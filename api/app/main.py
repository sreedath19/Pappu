import os
from typing import List

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


STORAGE_ACCOUNT_NAME = os.getenv("STORAGE_ACCOUNT_NAME")
PDF_CONTAINER_NAME = os.getenv("PDF_CONTAINER_NAME", "pdf-uploads")

if not STORAGE_ACCOUNT_NAME:
  raise RuntimeError("STORAGE_ACCOUNT_NAME environment variable must be set.")


def get_blob_service_client() -> BlobServiceClient:
  account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
  credential = DefaultAzureCredential()
  return BlobServiceClient(account_url=account_url, credential=credential)


app = FastAPI(
    title="PDF Upload Service",
    description="A simple microservice for uploading PDF documents.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # adjust as needed
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", summary="Health check")
async def health_check():
    return {"status": "ok"}


@app.post(
    "/upload-pdf",
    summary="Upload a single PDF document",
)
async def upload_pdf(file: UploadFile = File(...)):
    # Basic content-type validation
    if file.content_type not in ("application/pdf", "application/x-pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed.")

    try:
        # Ensure filename is safe-ish (you can harden this if needed)
        filename = os.path.basename(file.filename)
        if not filename.lower().endswith(".pdf"):
            filename = f"{filename}.pdf"

        blob_service_client = get_blob_service_client()
        container_client = blob_service_client.get_container_client(PDF_CONTAINER_NAME)
        # Create container if it does not already exist (idempotent)
        try:
            container_client.create_container()
        except Exception:
            # Likely already exists or you don't have permission to create; ignore in that case
            pass

        blob_client = container_client.get_blob_client(filename)
        contents = await file.read()
        blob_client.upload_blob(contents, overwrite=True)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to upload file to blob storage: {exc}")
    finally:
        await file.close()

    return JSONResponse(
        {
            "message": "File uploaded successfully.",
            "filename": filename,
        }
    )


@app.post(
    "/upload-pdfs",
    summary="Upload multiple PDF documents",
)
async def upload_pdfs(files: List[UploadFile] = File(...)):
    saved_files = []
    try:
        blob_service_client = get_blob_service_client()
        container_client = blob_service_client.get_container_client(PDF_CONTAINER_NAME)
        try:
            container_client.create_container()
        except Exception:
            pass

        for file in files:
            if file.content_type not in ("application/pdf", "application/x-pdf"):
                raise HTTPException(
                    status_code=400,
                    detail=f"File '{file.filename}' is not a valid PDF.",
                )

            filename = os.path.basename(file.filename)
            if not filename.lower().endswith(".pdf"):
                filename = f"{filename}.pdf"

            try:
                contents = await file.read()
                blob_client = container_client.get_blob_client(filename)
                blob_client.upload_blob(contents, overwrite=True)
                saved_files.append(filename)
            except Exception as exc:
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to upload file '{file.filename}' to blob storage: {exc}",
                )
            finally:
                await file.close()
    except HTTPException:
        # re-raise validation or upload errors
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error while uploading files: {exc}",
        )

    return JSONResponse(
        {
            "message": "Files uploaded successfully.",
            "files": saved_files,
        }
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

