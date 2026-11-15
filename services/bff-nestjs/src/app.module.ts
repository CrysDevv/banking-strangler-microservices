import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TerminusModule } from '@nestjs/terminus';
import { RedisService } from './modules/redis/redis.service';
import { BankingBffService } from './modules/banking/banking.service';
import { BankingBffController } from './modules/banking/banking.controller';
import { HealthController } from './modules/health/health.controller';
import { CorrelationIdMiddleware } from './common/interceptors/correlation-id.middleware';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TerminusModule,
  ],
  controllers: [BankingBffController, HealthController],
  providers: [RedisService, BankingBffService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(CorrelationIdMiddleware).forRoutes('*');
  }
}
