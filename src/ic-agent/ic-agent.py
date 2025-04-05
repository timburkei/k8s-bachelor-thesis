import os, io, time, json, logging, uuid
from azure.storage.blob import BlobServiceClient
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from PIL import Image


logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

azure_storage_connection_string = os.getenv("AZURE_BLOB_STORAGE_CONNECTION_STRING")
input_azure_storage_container_name = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")
input_service_bus_connection_string = os.getenv("INPUT_SERVICE_BUS_CONNECTION_STRING")
input_service_bus_queue_name = os.getenv("INPUT_SERVICE_BUS_QUEUE_NAME")
compression_percentage = os.getenv("COMPRESSION_PERCENTAGE")
max_message_count = os.getenv("MAX_MESSAGE_COUNT")
output_azure_storage_container_name = os.getenv("OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")

if not azure_storage_connection_string:
    raise ValueError("AZURE_BLOB_STORAGE_CONNECTION_STRING is required")
if not input_azure_storage_container_name:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME is required")
if not input_service_bus_connection_string:
    raise ValueError("INPUT_SERVICE_BUS_CONNECTION_STRING is required")
if not input_service_bus_queue_name:
    raise ValueError("INPUT_SERVICE_BUS_QUEUE_NAME is required")
if not compression_percentage:
    raise ValueError("COMPRESSION_PERCENTAGE is required")
if not max_message_count:
    raise ValueError("MAX_MESSAGE_COUNT is required")
if not output_azure_storage_container_name:
    raise ValueError("OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME is required")

blob_service_client = BlobServiceClient.from_connection_string(azure_storage_connection_string)
input_service_bus_client = ServiceBusClient.from_connection_string(input_service_bus_connection_string)


def compress_image(image_data):
    print(f"✅ Starting Process (Image Compression)")
    with io.BytesIO(image_data) as input_stream:
        img = Image.open(input_stream)
        output_stream = io.BytesIO()
        quality = int(compression_percentage)
        img.save(output_stream, format="JPEG", quality=quality)
        output_stream.seek(0)
        return output_stream.getvalue()
    print(f"⛔ End of the process (Image Compression)")

def save_compressed_image(image_data, image_name):
    print(f"✅ Starting Process (Save compressed Image) - Save {image_name} to output blob storage")

    try:
        output_blob_client = blob_service_client.get_blob_client(
            container=output_azure_storage_container_name,
            blob=image_name
        )
        output_blob_client.upload_blob(image_data, overwrite=True)

        image_url = f"https://{blob_service_client.account_name}.blob.core.windows.net/{output_azure_storage_container_name}/{image_name}"
        print(f"⛔ End of Process (Save compressed Image) - Save {image_name} to output blob storage")
        return image_url

    except Exception as e:
        print(f"❗ERROR - Step 6 (Save compressed Image) - Error when saving the image {e}")
        raise


def process_message():
    print(f"✅ Starting Step 4 (Process Message) - Connect to Azure Service Bus and get the next message")

    # Verwendung des Peek-Lock-Mechanismus für zuverlässiges Messaging
    try:
        with input_service_bus_client.get_queue_receiver(
            queue_name=input_service_bus_queue_name,
            max_wait_time=15
        ) as receiver:
            messages = receiver.receive_messages(max_message_count=int(max_message_count))

            # Nichts zu tun, wenn keine Nachrichten vorhanden sind
            if not messages:
                print("no messages found")
                return

            # Verarbeitung der abgerufenen Nachricht
            for msg in messages:
                try:
                    # Blob-Name aus der Nachricht extrahieren
                    if hasattr(msg.body, '__iter__') and not isinstance(msg.body, (bytes, str)):
                        # Handle generator case by consuming it
                        message_content = b''.join(list(msg.body))
                    else:
                        message_content = msg.body

                    # JSON-Nachricht parsen
                    message_json = json.loads(message_content.decode("utf-8"))
                    logging.info(f"JSON-Nachricht empfangen: {message_json}")

                    # Bild-URL oder Namen aus der JSON-Nachricht extrahieren
                    if "content" in message_json and "image_uploaded" in message_json["content"]:
                        image_blob_name = message_json["content"]["image_uploaded"]
                        logging.info(f"Bild-Name extrahiert: {image_blob_name}")
                    else:
                        raise ValueError("Ungültiges Nachrichtenformat: 'image_uploaded' nicht gefunden")

                     # Extract load_testing_id if present
                    load_testing_id = None
                    if "content" in message_json and "load_testing_id" in message_json["content"]:
                        load_testing_id = message_json["content"]["load_testing_id"]
                        logging.info(f"Load testing ID extracted: {load_testing_id}")

                    # Schritt 5: Herunterladen des Bildes aus dem Input Blob Storage
                    logging.info(f"Schritt 5: Herunterladen des Bildes {image_blob_name} aus Input Blob Storage")
                    input_blob_client = blob_service_client.get_blob_client(
                        container=input_azure_storage_container_name, 
                        blob=image_blob_name
                    )
                    image_data = input_blob_client.download_blob().readall()
                    logging.info(f"Bild erfolgreich heruntergeladen, Größe: {len(image_data)} Bytes")

                    # Komprimieren des Bildes (zwischen Schritt 5 und 6)
                    logging.info("Komprimieren des Bildes")
                    compressed_image = compress_image(image_data)
                    compressed_image_name = f"compressed_{image_blob_name}"
                    logging.info(f"Bild komprimiert, neue Größe: {len(compressed_image)} Bytes")

                    # Schritt 6: Speichern des komprimierten Bildes
                    image_url = save_compressed_image(compressed_image, compressed_image_name)

                    receiver.complete_message(msg)

                    logging.info(f"Verarbeitung für {image_blob_name} abgeschlossen")

                except Exception as e:
                    logging.error(f"Fehler bei der Verarbeitung: {e}")
                    receiver.abandon_message(msg)

    except Exception as e:
        logging.error(f"Fehler bei der Verbindung zum Service Bus: {e}")

def initialize_containers():
    """Initialisiert die benötigten Container, falls sie nicht existieren"""
    try:
        # Input Container erstellen
        input_container_client = blob_service_client.get_container_client(input_azure_storage_container_name)
        if not input_container_client.exists():
            input_container_client.create_container()
            logging.info(f"Input container {input_azure_storage_container_name} created")
        
        # Output Container erstellen
        output_container_client = blob_service_client.get_container_client(output_azure_storage_container_name)
        if not output_container_client.exists():
            output_container_client.create_container()
            logging.info(f"Output container {output_azure_storage_container_name} created")
    
    except Exception as e:
        logging.error(f"Fehler bei der Initialisierung der Container: {e}")
        raise

def main():
    print("Image Compression Agent started")
    
    try:
        # Container initialisieren
        initialize_containers()
        
        # Endlosschleife für kontinuierliche Verarbeitung
        while True:
            try:
                # Nachrichten aus der Service Bus Queue verarbeiten
                process_message()
                
                # Kurze Pause um die CPU nicht zu überlasten
                time.sleep(1)
                
            except Exception as e:
                logging.error(f"Fehler im Hauptprozess: {e}")
                time.sleep(5)  # Bei Fehler etwas länger warten
    
    except Exception as e:
        logging.error(f"Kritischer Fehler: {e}")
        return

if __name__ == "__main__":
    main()