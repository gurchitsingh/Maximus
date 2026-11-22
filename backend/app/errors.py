"""One error shape for every non-2xx response (CONTRACTS 3.5)."""
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

log = logging.getLogger("maximus")


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, retry_after_s: int | None = None, details: dict | None = None):
        self.status, self.code, self.message = status, code, message
        self.retry_after_s, self.details = retry_after_s, details


def error_response(status, code, message, retry_after_s=None, details=None) -> JSONResponse:
    headers = {"Retry-After": str(retry_after_s)} if retry_after_s is not None else None
    body = {"error": {"code": code, "message": message, "retry_after_s": retry_after_s, "details": details}}
    return JSONResponse(body, status_code=status, headers=headers)


def install_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_: Request, e: ApiError):
        return error_response(e.status, e.code, e.message, e.retry_after_s, e.details)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, e: RequestValidationError):
        fields = [{"loc": ".".join(str(p) for p in err["loc"]), "msg": err["msg"]} for err in e.errors()]
        return error_response(422, "validation_error", "Invalid request.", details={"fields": fields})

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, e: StarletteHTTPException):
        if e.status_code in (404, 405):
            return error_response(e.status_code, "not_found", "Unknown path or method.")
        return error_response(e.status_code, "bad_request", str(e.detail), details={"reason": str(e.detail)})

    @app.exception_handler(Exception)
    async def _any(_: Request, e: Exception):
        log.exception("unhandled error")
        return error_response(500, "internal_error", "Something went wrong.")
