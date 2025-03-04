import os
import json
import logging
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("lt-agent")

# Create FastAPI instance
app = FastAPI(title="Load Testing Agent", description="Receives and displays data from co-agent")

@app.post("/test-data")
async def process_data(request: Request):
    """
    Endpoint that receives data from co-agent and displays it.
    Returns the exact same data as received.
    """
    try:
        # Get raw request body
        body = await request.body()
        
        # Try to parse as JSON
        try:
            data = json.loads(body)
            logger.info(f"Received JSON data: {data}")
            print(f"✅ Received data: {json.dumps(data, indent=2)}")
            
            # Validate if expected data is present
            if isinstance(data, dict) and "compressed_image_url" in data:
                logger.info(f"Processing image URL: {data['compressed_image_url']}")
                print(f"✅ Processing image URL: {data['compressed_image_url']}")
                
                # Check for load_testing_id
                if "load_testing_id" in data:
                    logger.info(f"Load testing ID: {data['load_testing_id']}")
                    print(f"✅ Load testing ID: {data['load_testing_id']}")
            
            # Return the same data
            return JSONResponse(content=data)
        
        except json.JSONDecodeError:
            # Handle non-JSON data
            data_str = body.decode('utf-8')
            logger.warning(f"Received non-JSON data: {data_str}")
            print(f"⚠️ Received non-JSON data: {data_str}")
            return {"received_data": data_str, "warning": "Data was not in JSON format"}
    
    except Exception as e:
        error_msg = f"Error processing request: {str(e)}"
        logger.error(error_msg)
        print(f"❌ {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)