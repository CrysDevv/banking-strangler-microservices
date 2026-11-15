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
    let detail: unknown = 'Ocurrió un error inesperado en el BFF.';
    let errorCode: string | number = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const errorResponse = exception.getResponse();
      if (typeof errorResponse === 'object' && errorResponse !== null) {
        const problem = errorResponse as Record<string, unknown>;
        title = typeof problem.title === 'string' ? problem.title : exception.name;
        detail = problem.message ?? problem.detail ?? exception.message;
        errorCode =
          typeof problem.errorCode === 'string' || typeof problem.errorCode === 'number'
            ? problem.errorCode
            : typeof problem.error === 'string'
              ? problem.error
              : 'HTTP_EXCEPTION';
      } else {
        detail = typeof errorResponse === 'string' ? errorResponse : exception.message;
      }
    } else if (exception instanceof Error) {
      detail = exception.message;
    }

    const problemDetails = {
      type: 'https://api.banking.com/errors/bff-error',
      title: title,
      status: status,
      detail: Array.isArray(detail)
        ? detail.join(', ')
        : typeof detail === 'string'
          ? detail
          : JSON.stringify(detail) ?? String(detail),
      instance: request.url,
      errorCode: errorCode,
      correlationId: correlationId,
      timestamp: new Date().toISOString(),
    };

    response.setHeader('Content-Type', 'application/problem+json');
    response.status(status).json(problemDetails);
  }
}
