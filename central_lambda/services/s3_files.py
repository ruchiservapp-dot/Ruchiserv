"""
S3 File Service — Presigned URL generation for image uploads/downloads.
Used by the central Lambda to handle files/upload-url and files/download-url routes.

Cost-optimized:
  - Images stored in S3 with Intelligent-Tiering
  - Presigned URLs avoid proxying through Lambda (saves data transfer costs)
  - Upload URLs expire in 5 minutes, download URLs in 1 hour
"""
import boto3
import uuid
from datetime import datetime

BUCKET_NAME = 'ruchiserv-files'

_s3_client = None

def get_s3():
    global _s3_client
    if _s3_client is None:
        from botocore.config import Config
        _s3_client = boto3.client(
            's3',
            region_name='ap-south-1',
            config=Config(s3={'addressing_style': 'virtual'}),
            endpoint_url='https://s3.ap-south-1.amazonaws.com',
        )
    return _s3_client


def generate_upload_url(firm_id: str, file_type: str, file_name: str = None) -> dict:
    """
    Generate a presigned PUT URL for uploading an image to S3.
    
    Args:
        firm_id: The firm's ID (used as top-level folder)
        file_type: Type of file - 'invoices', 'staff_photos', 'utensils'
        file_name: Optional custom filename. Auto-generated if not provided.
    
    Returns:
        dict with uploadUrl, s3Key, downloadUrl
    """
    s3 = get_s3()
    
    # Generate unique filename if not provided
    if not file_name:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        unique_id = str(uuid.uuid4())[:8]
        file_name = f"{file_type}_{timestamp}_{unique_id}.jpg"
    
    # S3 key: firmId/fileType/filename
    s3_key = f"{firm_id}/{file_type}/{file_name}"
    
    # Generate presigned PUT URL (5 min expiry)
    upload_url = s3.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': BUCKET_NAME,
            'Key': s3_key,
            'ContentType': 'image/jpeg',
        },
        ExpiresIn=300,  # 5 minutes
    )
    
    return {
        'uploadUrl': upload_url,
        's3Key': s3_key,
        'bucket': BUCKET_NAME,
    }


def generate_download_url(s3_key: str) -> dict:
    """
    Generate a presigned GET URL for downloading/viewing an image from S3.
    
    Args:
        s3_key: The S3 object key (e.g., 'RUCHOW1D/invoices/inv_123.jpg')
    
    Returns:
        dict with downloadUrl
    """
    s3 = get_s3()
    
    download_url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': BUCKET_NAME,
            'Key': s3_key,
        },
        ExpiresIn=3600,  # 1 hour
    )
    
    return {
        'downloadUrl': download_url,
        's3Key': s3_key,
    }
