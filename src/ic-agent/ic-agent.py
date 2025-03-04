import os, io, time, json, logging, uuid
from azure.storage.blob import BlobServiceClient
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from PIL import Image


logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

# Input configuration
input_azure_storage_connection_string = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING")
input_azure_storage_container_name = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")
input_service_bus_connection_string = os.getenv("INPUT_SERVICE_BUS_CONNECTION_STRING")
input_service_bus_queue_name = os.getenv("INPUT_SERVICE_BUS_QUEUE_NAME")
compression_percentage = os.getenv("COMPRESSION_PERCENTAGE")
max_message_count = os.getenv("MAX_MESSAGE_COUNT")

if not input_azure_storage_connection_string:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING is required")
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

# Output configuration
output_azure_storage_connection_string = os.getenv("OUTPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING")
output_azure_storage_container_name = os.getenv("OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")
output_service_bus_connection_string = os.getenv("OUTPUT_SERVICE_BUS_CONNECTION_STRING")
output_service_bus_queue_name = os.getenv("OUTPUT_SERVICE_BUS_QUEUE_NAME")

if not output_azure_storage_connection_string:
    raise ValueError("OUTPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING is required")
if not output_azure_storage_container_name:
    raise ValueError("OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME is required")
if not output_service_bus_connection_string:
    raise ValueError("OUTPUT_SERVICE_BUS_CONNECTION_STRING is required")
if not output_service_bus_queue_name:
    raise ValueError("OUTPUT_SERVICE_BUS_QUEUE_NAME is required")

# Initialize clients
input_blob_service_client = BlobServiceClient.from_connection_string(input_azure_storage_connection_string)
output_blob_service_client = BlobServiceClient.from_connection_string(output_azure_storage_connection_string)
input_service_bus_client = ServiceBusClient.from_connection_string(input_service_bus_connection_string)
output_service_bus_client = ServiceBusClient.from_connection_string(output_service_bus_connection_string)

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

# Step 6: Save compressed image
def save_compressed_image(image_data, image_name):
    print(f"✅ Starting Step 6 (Save compressed Image) - Save {image_name} to output blob storage")

    try:
         # Ensure that the container exists
        output_container_client = output_blob_service_client.get_container_client(output_azure_storage_container_name)
        if not output_container_client.exists():
            output_container_client.create_container()
            logging.info(f"Output container {output_azure_storage_container_name} created")

        # Upload image
        output_blob_client = output_blob_service_client.get_blob_client(
            container=output_azure_storage_container_name, 
            blob=image_name
        )
        output_blob_client.upload_blob(image_data, overwrite=True)

        # Generated URL
        image_url = f"https://{output_blob_service_client.account_name}.blob.core.windows.net/{output_azure_storage_container_name}/{image_name}"
        logging.info(f"Bild erfolgreich gespeichert: {image_url}")
        print(f"⛔ End of Step 6 (Save compressed Image) - Save {image_name} to output blob storage")
        return image_url

    except Exception as e:
        print(f"❗Step 6 (Save compressed Image) - Error when saving the image {e}")
        raise


# Step 9: Send Message with compresses image url to Message Queue
def send_message_to_output_queue(image_url):
    logging.info(f"Step 9: Send URL to output queue: {image_url}")
    print(f"✅ Starting Step 9 (Send Message to Output Queue) - Send {image_url} to output service bus queue")

    try:
        conversation_id = str(uuid.uuid4())
        fipa_acl_message = {
            "performative": "inform",
            "sender": "ica",
            "receiver": "oca",
            "conversation_id": conversation_id,
            "content": {
                "compressed_image_url": image_url
            },
            "language": "ACL",
            "encoding": "UTF-8"
        }

        with output_service_bus_client.get_queue_sender(output_service_bus_queue_name) as sender:
            # Convert message to JSON string
            message_json = json.dumps(fipa_acl_message)
            message = ServiceBusMessage(message_json)
            sender.send_messages(message)

            print(f"⛔ End of Step 9 (Send Message to Output Queue) - FIPA ACL message sent to output service bus queue")
            logging.info(f"FIPA ACL message sent to Service Bus. Conversation ID: {conversation_id}")
    except Exception as e:
        logging.error(f"Fehler beim Senden der FIPA ACL Nachricht an die Output Queue: {e}")
        print(f"❗Step 9 (Send Message to Output Queue) - Error when sending the message {e}")
        raise

# Step 4 to 8
def process_message():
    logging.info("Schritt 4: Verbindung zum Azure Service Bus und Abrufen der nächsten Nachricht")
    print(f"✅ Starting Step 4 (Process Message) - Connect to Azure Service Bus and get the next message")

    # Verwendung des Peek-Lock-Mechanismus für zuverlässiges Messaging
    try:
        with input_service_bus_client.get_queue_receiver(
            queue_name=input_service_bus_queue_name,
            max_wait_time=5
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

                    # Schritt 5: Herunterladen des Bildes aus dem Input Blob Storage
                    logging.info(f"Schritt 5: Herunterladen des Bildes {image_blob_name} aus Input Blob Storage")
                    input_blob_client = input_blob_service_client.get_blob_client(
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
                    
                    # Schritt 7: Warten auf die Bestätigung der Speicherung
                    logging.info("Schritt 7: Warten auf Bestätigung der Speicherung")
                    # Die Funktion save_compressed_image ist synchron, also ist die Speicherung bereits abgeschlossen
                    # In einer asynchronen Umgebung müssten wir hier auf die Bestätigung warten
                    
                    # Schritt 8: Bestätigen und Löschen der Nachricht aus der Input Queue
                    logging.info("Schritt 8: Nachricht in der Input Queue als verarbeitet markieren")
                    receiver.complete_message(msg)
                    
                    # Schritt 9: Senden der URL an die Output Queue
                    send_message_to_output_queue(image_url)
                    
                    logging.info(f"Verarbeitung für {image_blob_name} abgeschlossen")
                    
                except Exception as e:
                    # Bei Fehlern die Nachricht zurück in die Queue stellen
                    logging.error(f"Fehler bei der Verarbeitung: {e}")
                    receiver.abandon_message(msg)
                    
    except Exception as e:
        logging.error(f"Fehler bei der Verbindung zum Service Bus: {e}")

def initialize_containers():
    """Initialisiert die benötigten Container, falls sie nicht existieren"""
    try:
        # Input Container erstellen
        input_container_client = input_blob_service_client.get_container_client(input_azure_storage_container_name)
        if not input_container_client.exists():
            input_container_client.create_container()
            logging.info(f"Input container {input_azure_storage_container_name} created")
        
        # Output Container erstellen
        output_container_client = output_blob_service_client.get_container_client(output_azure_storage_container_name)
        if not output_container_client.exists():
            output_container_client.create_container()
            logging.info(f"Output container {output_azure_storage_container_name} created")
    
    except Exception as e:
        logging.error(f"Fehler bei der Initialisierung der Container: {e}")
        raise

def main():
    """Hauptfunktion für den Agenten"""
    logging.info("Image Compression Agent gestartet")
    
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