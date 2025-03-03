import os, io
from azure.storage.blob import BlobServiceClient
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from PIL import Image
import logging

#Input
input_azure_storage_connection_string = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING")
input_azure_storage_container_name = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")
#input_service_bus_connection_string = os.getenv("INPUT_SERVICE_BUS_CONNECTION_STRING")
#input_service_bus_queue_name = os.getenv("INPUT_SERVICE_BUS_QUEUE_NAME")

if not input_azure_storage_connection_string:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING is required")
if not input_azure_storage_container_name:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME is required")
#if not input_service_bus_connection_string:
#    raise ValueError("INPUT_SERVICE_BUS_CONNECTION_STRING is required")
#if not input_service_bus_queue_name:
#    raise ValueError("INPUT_SERVICE_BUS_QUEUE_NAME is required")

#Output
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


input_blob_service_client = BlobServiceClient.from_connection_string(input_azure_storage_connection_string)
output_blob_service_client = BlobServiceClient.from_connection_string(output_azure_storage_connection_string)
service_bus_client = ServiceBusClient.from_connection_string(output_service_bus_connection_string)

def compress_image(image_data):
    with io.BytesIO(image_data) as input_stream:
        img = Image.open(input_stream)
        output_stream = io.BytesIO()
        img.save(output_stream, format="JPEG", quality=50)
        output_stream.seek(0)
        return output_stream.getvalue()

# 6. Save image in Azure Blob Storage
def save_compressed_image(image_data, image_name):
    output_blob_client = output_blob_service_client.get_blob_client(container=output_azure_storage_container_name, blob=image_name)
    output_blob_client.upload_blob(image_data, overwrite=True)

    image_url = f"https://{output_blob_service_client.account_name}.blob.core.windows.net/{output_azure_storage_container_name}/{image_name}"
    return image_url

# 7. Send Image-URL an Azure Service Bus Output
def send_message_to_output_queue(image_url):
    with service_bus_client.get_queue_sender(output_service_bus_queue_name) as sender:
        message = ServiceBusMessage(image_url)
        sender.send_messages(message)
        print(f"URL sent to output queue: {image_url}")

def process_message():
    with service_bus_client.get_queue_receiver(output_service_bus_queue_name) as receiver:
        messages = receiver.receive_messages(max_message_count=1, max_wait_time=5)

        for msg in messages:
            try:
                image_blob_name = msg.body.decode("utf-8")

                input_blob_client = input_blob_service_client.get_blob_client(container=input_azure_storage_container_name, blob=image_blob_name)
                image_data = input_blob_client.download_blob().readall()

                compressed_image = compress_image(image_data)

                # Speichern des komprimierten Bildes im Output Blob Storage
                compressed_image_name = f"compressed_{image_blob_name}"
                image_url = save_compressed_image(compressed_image, compressed_image_name)

                # Nachricht mit URL an die Output Queue senden
                send_message_to_output_queue(image_url)

                # Bestätigung der Verarbeitung
                receiver.complete_message(msg)
                print(f"Image {image_blob_name} processed and stored under {image_url}")

            except Exception as e:
                print(f"❌ Processing errors: {e}")
                receiver.abandon_message(msg)  # Nachricht in Queue zurückstellen, falls Fehler
