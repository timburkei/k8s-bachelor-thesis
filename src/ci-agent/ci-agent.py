from fastapi import FastAPI, File, HTTPException, UploadFile
import io, os, uuid, json
from PIL import Image
import logging
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
from azure.servicebus import ServiceBusClient, ServiceBusMessage

app = FastAPI()

logging.basicConfig(level=logging.INFO)

input_azure_storage_connection_string = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING")
input_azure_storage_container_name = os.getenv("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME")
input_service_bus_connection_string = os.getenv("INPUT_SERVICE_BUS_CONNECTION_STRING")
input_service_bus_queue_name = os.getenv("INPUT_SERVICE_BUS_QUEUE_NAME")

if not input_azure_storage_connection_string:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING is required")
if not input_azure_storage_container_name:
    raise ValueError("INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME is required")
if not input_service_bus_connection_string:
    raise ValueError("INPUT_SERVICE_BUS_CONNECTION_STRING is required")
if not input_service_bus_queue_name:
    raise ValueError("INPUT_SERVICE_BUS_QUEUE_NAME is required")

@app.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    try:
        if file.content_type != "image/jpeg":
            raise HTTPException(status_code=400, detail="Only JPEG images are supported")

        logging.info(f"Uploading image: {file.filename}")
        image = Image.open(io.BytesIO(await file.read()))
        logging.info(f"Image uploaded: {file.filename}, Größe: {image.size}")

        # Generate a unique filename
        unique_filename = f"{uuid.uuid4()}.jpg"

        # Convert image to bytes
        image_byte_arr = io.BytesIO()
        image.save(image_byte_arr, format='JPEG')
        image_byte_arr = image_byte_arr.getvalue()

        # Upload image to Azure Blob Storage
        input_blob_service_client = BlobServiceClient.from_connection_string(input_azure_storage_connection_string)
        input_blob_container_client = input_blob_service_client.get_container_client(input_azure_storage_container_name)

        if not input_blob_container_client.exists():
            logging.info("Container does not exist, create container...")
            try:
                input_blob_container_client.create_container()
            except Exception as e:
                logging.error(f"Error creating container: {e}")
                raise HTTPException(status_code=500, detail="Error: creating container")

        blob_client = input_blob_container_client.get_blob_client(unique_filename)
        blob_client.upload_blob(image_byte_arr, blob_type="BlockBlob")

        # Get the URL of the uploaded blob
        blob_url = blob_client.url
        logging.info(f"Blob URL: {blob_url}")

        # Send a message to Azure Service Bus
        conversation_id = str(uuid.uuid4())
        fipa_acl_message = {
            "performative": "inform",
            "sender": "cia",
            "receiver": "ica",
            "conversation_id": conversation_id,
            "content": {
                "image_uploaded": unique_filename,
                "url": blob_url
            },
            "language": "ACL",
            "encoding": "UTF-8"
        }

        service_bus_client = ServiceBusClient.from_connection_string(input_service_bus_connection_string)

        with service_bus_client.get_queue_sender(input_service_bus_queue_name) as sender:
            # Convert dictionary to JSON string for transmission
            message_json = json.dumps(fipa_acl_message)
            message = ServiceBusMessage(message_json)
            sender.send_messages(message)
            logging.info(f"FIPA ACL message sent to Service Bus. Conversation ID: {conversation_id}")

        return {"message": "Image uploaded successfully", "url": blob_url}

    except Exception as e:
        logging.error(f"Error uploading image: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")