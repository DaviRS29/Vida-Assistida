import {
  Global,
  Injectable,
  Logger,
  Module,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createTransport, Transporter } from 'nodemailer';

/**
 * Envio de e-mails transacionais. Sem SMTP configurado, a mensagem é
 * registrada no log da API (somente fora de produção), para demonstração.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: Transporter | null;
  private readonly from: string;
  private readonly production: boolean;

  constructor(config: ConfigService) {
    const host = config.get<string>('SMTP_HOST');
    this.production = config.get<string>('NODE_ENV') === 'production';
    this.from = config.get<string>(
      'MAIL_FROM',
      'Vida Assistida <nao-responda@vidaassistida.app>',
    );
    this.transporter = host
      ? createTransport({
          host,
          port: Number(config.get('SMTP_PORT', 587)),
          secure: Number(config.get('SMTP_PORT', 587)) === 465,
          auth: config.get<string>('SMTP_USER')
            ? {
                user: config.get<string>('SMTP_USER'),
                pass: config.get<string>('SMTP_PASS'),
              }
            : undefined,
        })
      : null;
  }

  get configured(): boolean {
    return this.transporter !== null;
  }

  async send(to: string, subject: string, text: string): Promise<void> {
    if (this.transporter) {
      await this.transporter.sendMail({ from: this.from, to, subject, text });
      return;
    }
    if (this.production) {
      throw new ServiceUnavailableException(
        'Envio de e-mail indisponível. Contate o suporte.',
      );
    }
    this.logger.log(`[e-mail para ${to}] ${subject}\n${text}`);
  }
}

@Global()
@Module({ providers: [MailService], exports: [MailService] })
export class MailModule {}
