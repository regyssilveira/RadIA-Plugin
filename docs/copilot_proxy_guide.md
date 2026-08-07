# Guia de Configuração: GitHub Copilot no Rad IA via Proxy Local (Fase 1)

Este guia orienta como utilizar sua assinatura corporativa ou pessoal do **GitHub Copilot** (e outros assistentes de IA baseados em nuvem) dentro do **Rad IA** sem a necessidade de implementar fluxos de autenticação complexos de forma nativa. 

Utilizando a nova funcionalidade de **Provedores Dinâmicos via JSON** (introduzida na versão `v0.0.6`), podemos integrar o Rad IA a um serviço de proxy local compatível com a API da OpenAI.

---

## ⚙️ Como funciona a arquitetura por Proxy?

O fluxo consiste em executar um serviço intermediário leve na sua própria máquina de desenvolvimento. Esse serviço cuida da autenticação (OAuth) segura com o GitHub e converte o tráfego da API interna do Copilot para o formato padrão da OpenAI:

```
[ Rad IA (Delphi IDE) ] 
       │  (Chamada padrão OpenAI)
       ▼
[ Proxy Local (Porta 8080) ] 
       │  (Autenticação e Proxy de Headers)
       ▼
[ Servidores do GitHub Copilot (Nuvem) ]
```

---

## 🛠️ Passo a Passo para Configurar o GitHub Copilot

O proxy open-source mais estável e utilizado para essa finalidade é o **[copilot-gpt4-service](https://github.com/aaamoon/copilot-gpt4-service)**.

### Passo 1: Executar o Proxy Local

Você pode executar o proxy local de duas formas rápidas:

#### Opção A: Via Docker (Recomendado)
Se você já possui o Docker instalado na sua máquina, execute o comando abaixo no terminal para iniciar o contêiner em background:
```bash
docker run -d --name copilot-gpt4-service -p 8080:8080 aaamoon/copilot-gpt4-service
```

#### Opção B: Download do Executável Nativo
1. Acesse as **[Releases do copilot-gpt4-service](https://github.com/aaamoon/copilot-gpt4-service/releases)**.
2. Baixe a versão correspondente ao seu sistema operacional (ex: `copilot-gpt4-service-windows-amd64.exe`).
3. Execute o arquivo baixado. Ele abrirá uma janela de terminal e começará a rodar por padrão na porta `8080` (`http://localhost:8080`).

---

### Passo 2: Obter o seu Token do GitHub Copilot

Uma vez que o proxy local esteja rodando, precisamos autenticar com sua conta do GitHub para gerar a chave de acesso local:

1. Abra o seu navegador e acesse a URL: **`http://localhost:8080/copilot/tokens`** (ou use `http://127.0.0.1:8080/copilot/tokens`).
2. O sistema do proxy fornecerá um link e um código PIN de autenticação de dispositivo (Device Flow) do GitHub.
3. Clique no link, faça login com sua conta do GitHub (que possui a assinatura ativa do Copilot) e insira o PIN fornecido.
4. Após a autorização, a página web exibirá um JSON contendo uma chave começada em **`ghu_...`** ou **`gho_...`**.
5. **Copie esse Token completo**. Ele será utilizado como a sua `apiKey`.

---

### Passo 3: Cadastrar o Provedor Dinâmico no Rad IA

Agora que você tem o proxy rodando e o seu token do Copilot em mãos:

1. No Windows, navegue até a pasta de provedores dinâmicos do Rad IA:
   * Pressione `Win + R`, digite `%APPDATA%\RadIA\providers\` e pressione `Enter`. (Se a pasta `providers` não existir, crie-a).
2. Crie um novo arquivo chamado **`github-copilot.json`**.
3. Abra o arquivo em um editor de texto e cole a seguinte configuração (substituindo o token pelo seu):

```json
{
  "id": "github-copilot",
  "displayName": "GitHub Copilot",
  "baseUrl": "http://localhost:8080/v1",
  "apiKey": "ghu_insira_seu_token_aqui_...",
  "defaultModels": [
    "gpt-5.4"
  ]
}
```

4. Salve o arquivo.

---

### Passo 4: Reiniciar a IDE do Delphi

1. Se a IDE do Delphi estiver aberta, feche-a e abra novamente.
2. O Rad IA detectará o arquivo `github-copilot.json`, validará o provedor dinâmico e o adicionará na lista de seleção de provedores do painel de chat.
3. **Pronto!** Suas conversas, explicações de código e refatorações no Rad IA agora serão processadas de forma segura e rápida através da infraestrutura de IA da sua conta do GitHub Copilot.

---

## 🔒 Segurança e Compliance Corporativo

*   **Isolamento de Credenciais**: O token `ghu_...` fica armazenado localmente na sua máquina de desenvolvimento.
*   **Tratamento de Dados**: Os dados e códigos enviados são transmitidos aos servidores seguros do GitHub de acordo com as regras contratadas da sua assinatura (incluindo cláusulas de não-treinamento de modelos em planos corporativos).
*   **Controle de Acesso**: Nenhuma credencial é enviada para servidores terceiros não autorizados. O proxy apenas assina e direciona a requisição original da VCL para os endpoints oficiais do GitHub.
