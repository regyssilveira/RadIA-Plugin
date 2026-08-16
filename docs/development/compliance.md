# Termos de Uso, Compliance Corporativo e Segurança de Dados

Este documento estabelece as diretrizes de compliance, termos de uso e políticas de privacidade de dados para o plugin **Rad IA**.

---

## 1. Aviso de Marcas Registradas (Trademark Disclaimer)
Todas as marcas mencionadas, incluindo *Embarcadero Delphi*, *Microsoft Windows*,
*Microsoft Edge*, *WebView2*, *Google Gemini*, *OpenAI ChatGPT*, *Anthropic Claude*, *DeepSeek*,
*Groq* e *Ollama*, pertencem aos seus respectivos proprietários. A menção serve apenas para
descrever compatibilidade, configuração e integração tecnológica.

O **Rad IA** é um projeto independente, open-source e não possui qualquer afiliação oficial, patrocínio ou associação comercial com os detentores dessas marcas.

---

## 2. Revisão Obrigatória de Código e Isenção de Responsabilidade
*   **Revisão por Humano:** O Rad IA é um assistente de produtividade que gera sugestões baseando-se em modelos de Inteligência Artificial de terceiros. Qualquer sugestão gerada (incluindo refatorações, correções de bugs, documentação e testes unitários) pode conter imprecisões, erros de lógica ou vulnerabilidades. O usuário é o **único responsável** por revisar, validar, testar e aprovar qualquer código gerado antes de utilizá-lo em ambientes de produção.
*   **Limitação de Responsabilidade:** Os criadores e contribuidores do Rad IA não serão responsabilizados por quaisquer danos, perdas de dados, lucros cessantes, falhas de segurança ou interrupções de serviço resultantes do uso do código sugerido ou do próprio funcionamento do plugin na IDE.

---

## 3. Segurança de Credenciais (BYOK)
O Rad IA adota a política de "Traga Sua Própria Chave" (BYOK - Bring Your Own Key):
*   As chaves de API fornecidas pelo usuário são armazenadas de forma segura e local na máquina do usuário, utilizando a API nativa de criptografia do Windows (**DPAPI - Data Protection API**).
*   Esses segredos são gravados diretamente no Registro do Windows do usuário logado e nunca são compartilhados ou enviados a servidores de telemetria ou terceiros.
*   Ao realizar requisições, as chaves são enviadas diretamente de forma segura aos endpoints oficiais de cada provedor correspondente.

---

## 4. Privacidade de Dados e Compliance Corporativo (LGPD / GDPR)
Ao utilizar provedores baseados em nuvem (Google Gemini, OpenAI, Anthropic, DeepSeek ou Groq), trechos do código-fonte selecionado no editor e informações de contexto do projeto são enviados para os servidores externos destas respectivas empresas para processamento.

*   **Uso Corporativo Restrito:** Para empresas e desenvolvedores trabalhando com código proprietário confidencial ou sob regras de conformidade corporativa rígidas (como LGPD ou GDPR), **recomendamos fortemente o uso do Ollama configurado localmente**.
*   **Privacidade Total:** Com modelos offline (como Llama 3, Phi-3 ou Mistral rodando no Ollama), todo o processamento das mensagens e códigos ocorre localmente na máquina ou servidor da rede interna, garantindo que nenhum dado confidencial saia da infraestrutura da empresa.

### Dados locais da plataforma agentiva

O RadIA mantém auditoria sanitizada em `%APPDATA%\RadIA\audit\tools.jsonl` e índices reconstruíveis
em `%APPDATA%\RadIA\Knowledge`. Esses dados permanecem locais, salvo quando uma ação autorizada
inclui conteúdo do projeto no contexto enviado ao provider selecionado.

Preserve a auditoria quando necessária para rastreabilidade. Remova índices somente com todas as
IDEs fechadas e conforme a política de retenção da organização.

### Proteções da superfície de chat e das exportações

*   **Renderização segura e Política de Segurança de Conteúdo (CSP):** o Markdown vindo do modelo
    escapa HTML bruto, remove imagens e rejeita links com esquemas executáveis. Como defesa adicional,
    chat e diff bloqueiam conexões, imagens remotas, frames e objetos pela CSP.
*   **Redação de segredos na exportação:** ao exportar a conversa para Markdown ou HTML, o conteúdo
    passa pelo redator de segredos, que substitui tokens `Bearer`, chaves de acesso AWS e campos
    JSON sensíveis (`api_key`, `password`, `authorization`, entre outros) por `[REDACTED]`.
*   **Redação nos logs de diagnóstico:** o resumo de payload gravado em `%APPDATA%\RadIA\Logs`
    aplica a mesma redação antes de truncar a amostra.
*   **Login de CLI sem interpretador de comandos:** a autenticação guiada executa o binário do CLI
    diretamente, sem passar por `cmd.exe`, de modo que caracteres especiais no caminho configurado
    não são interpretados como comandos.
