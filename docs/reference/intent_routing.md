# Roteamento de intenção

O RadIA usa um classificador local e determinístico para reconhecer objetivos comuns sem enviar o
texto a outro serviço e sem executar tools. Nesta primeira cobertura, ele recomenda jornadas para:

- criar um projeto Delphi completo;
- diagnosticar e corrigir uma falha de build;
- executar e interpretar testes;
- reproduzir e diagnosticar uma falha em runtime.

O resultado contém intenção, confiança (`high` ou `medium`), rota, comando e explicação. Ele aparece
como recomendação, nunca como autorização. O usuário decide entre:

1. **Use recommended route:** confirma o comando armazenado pelo host;
2. **Review command:** copia o comando para o compositor, onde pode ser alterado;
3. **Continue as chat:** descarta a recomendação e usa a rota de conversa atual.

Um novo prompt invalida a recomendação anterior. A WebView não pode escolher outro comando durante
a confirmação: o host aceita somente o comando pendente que ele próprio classificou. Comandos que
começam com `/`, perguntas comuns e pedidos ambíguos não são interceptados.

## Limites e segurança

- A classificação não ativa o modo agente, não troca provider ou executor e não inicia uma tool.
- O texto do usuário permanece sujeito ao limite e às validações da jornada depois da confirmação.
- Plano, consentimento, workspace boundary, fingerprint e rollback continuam obrigatórios.
- O nível de confiança descreve apenas a correspondência da intenção; não comprova que a ação terá
  sucesso nem substitui diagnóstico de pré-requisitos.
- Não há telemetria remota do prompt ou da decisão. Evoluções futuras podem registrar somente
  contadores locais sanitizados e desativáveis.

Consulte [Jornadas Delphi](../guides/user_guide_journeys.md) para os fluxos disponíveis e
[Modelo de segurança](tool_security_model.md) para as proteções aplicadas após a confirmação.
