import os
import time
import json
import logging
import requests
from azure.servicebus import ServiceBusClient

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

# Configuration
output_service_bus_connection_string = os.getenv("OUTPUT_SERVICE_BUS_CONNECTION_STRING")
output_service_bus_queue_name = os.getenv("OUTPUT_SERVICE_BUS_QUEUE_NAME")
rest_endpoint_url = os.getenv("AZURE_LOAD_TESTING_API_URL")
max_message_count = int(os.getenv("MAX_MESSAGE_COUNT", "1"))

# Validate required environment variables
if not output_service_bus_connection_string:
    raise ValueError("OUTPUT_SERVICE_BUS_CONNECTION_STRING is required")
if not output_service_bus_queue_name:
    raise ValueError("OUTPUT_SERVICE_BUS_QUEUE_NAME is required")
if not rest_endpoint_url:
    raise ValueError("AZURE_LOAD_TESTING_API_URL is required")

# Initialize client
service_bus_client = ServiceBusClient.from_connection_string(output_service_bus_connection_string)

def forward_to_rest_endpoint(image_url, load_testing_id=None):
    """Sends the image URL and load_testing_id to the configured REST endpoint"""
    logging.info(f"Forwarding image URL to REST endpoint: {image_url}")
    print(f"✅ Forwarding to REST endpoint: {image_url}")

    try:
        payload = {"compressed_image_url": image_url}
        if load_testing_id is not None:
            payload["load_testing_id"] = load_testing_id

        response = requests.post(rest_endpoint_url, json=payload)
        response.raise_for_status()

        logging.info(f"Successfully forwarded to REST endpoint. Response: {response.status_code}")
        print(f"✅ Successfully forwarded. Response: {response.status_code}")
        return True

    except Exception as e:
        logging.error(f"Error forwarding to REST endpoint: {e}")
        print(f"❌ Error forwarding to REST endpoint: {e}")
        raise

def process_messages():
    """Process messages from the Service Bus Queue"""
    logging.info(f"Checking for messages in queue: {output_service_bus_queue_name}")
    print(f"✅ Checking for messages in queue: {output_service_bus_queue_name}")

    try:
        with service_bus_client.get_queue_receiver(
            queue_name=output_service_bus_queue_name,
            max_wait_time=5
        ) as receiver:
            messages = receiver.receive_messages(max_message_count=max_message_count)

            if not messages:
                print("No messages available in queue")
                return

            for msg in messages:
                try:
                    # Extract message content
                    if hasattr(msg.body, '__iter__') and not isinstance(msg.body, (bytes, str)):
                        message_content = b''.join(list(msg.body))
                    else:
                        message_content = msg.body
                    # Parse JSON message
                    message_json = json.loads(message_content.decode("utf-8"))
                    logging.info(f"Received message: {message_json}")
                    # Extract image URL from the message
                    if "content" in message_json and "compressed_image_url" in message_json["content"]:
                        image_url = message_json["content"]["compressed_image_url"]
                        logging.info(f"Extracted image URL: {image_url}")
                    else:
                        raise ValueError("Invalid message format: 'compressed_image_url' not found")
                    load_testing_id = None
                    if "content" in message_json and "load_testing_id" in message_json["content"]:
                        load_testing_id = message_json["content"]["load_testing_id"]
                        logging.info(f"Load testing ID extracted: {load_testing_id}")
                    # Forward to REST endpoint
                    forward_to_rest_endpoint(image_url, load_testing_id)
                    # Mark message as processed
                    receiver.complete_message(msg)
                    logging.info(f"Message processing completed for: {image_url}")
                except Exception as e:
                    logging.error(f"Error processing message: {e}")
                    receiver.abandon_message(msg)
    except Exception as e:
        logging.error(f"Error connecting to Service Bus: {e}")

def main():
    """Main function for the agent"""
    logging.info("CO-Agent started")
    print("CO-Agent started - listening for messages on Service Bus queue")
    try:
        while True:
            try:
                process_messages()
                time.sleep(1)  # Short pause between polling cycles
            except Exception as e:
                logging.error(f"Error in processing cycle: {e}")
                time.sleep(5)  # Longer pause in case of errors
    except KeyboardInterrupt:
        logging.info("CO-Agent stopping")
        print("CO-Agent stopping")
    except Exception as e:
        logging.error(f"Critical error: {e}")

if __name__ == "__main__":
    main()