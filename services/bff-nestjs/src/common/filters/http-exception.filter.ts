import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const correlationId = request.headers['x-correlation-id'] || 'N/A';

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let title = 'Error Interno del Servidor';
    let detail = 'Ocurrió un error inesperado en el BFF.';
    let errorCode = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const errorResponse: any = exception.getResponse();
      title = exception.name;
      detail = typeof errorResponse === 'object' && errorResponse.message ? errorResponse.message : exception.message;
      errorCode = typeof errorResponse === 'object' && errorResponse.error ? errorResponse.error : 'HTTP_EXCEPTION';
    } else if (exception instanceof Error) {
      detail = exception.message;
    }

    const problemDetails = {
      type: 'https://api.banking.com/errors/bff-error',
      title: title,
      status: status,
      detail: Array.isArray(detail) ? detail.join(', ') : detail,
      instance: request.url,
      errorCode: errorCode,
      correlationId: correlationId,
      timestamp: new Date().toISOString(),
    };

    response.setHeader('Content-Type', 'application/problem+json');
    response.status(status).json(problemDetails);
  }
}
