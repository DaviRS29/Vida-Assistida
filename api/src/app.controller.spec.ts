import { AppController } from './app.controller';

describe('AppController', () => {
  it('retorna o estado de saúde da API', () => {
    const result = new AppController().getHealth();

    expect(result.name).toBe('Vida Assistida API');
    expect(result.status).toBe('ok');
    expect(Date.parse(result.timestamp)).not.toBeNaN();
  });
});
