# ESystemShop

Controle de vendas na Shopee: lucro após taxas, estoque e contas a pagar (boletos).
O site é estático (HTML + JavaScript) e os dados ficam no **Supabase**.

## O que o sistema faz

- **Painel**: faturamento, lucro líquido, margem, boletos em aberto, valor do estoque, gráfico diário e alertas.
- **Vendas**: ao lançar um pedido, desconta automaticamente a taxa da Shopee pela faixa de preço, baixa o estoque e calcula o lucro. Excluir a venda devolve os itens ao estoque. Sem estoque suficiente, dá para comprar do fornecedor no boleto (à vista ou parcelado): os boletos entram em Contas a pagar e o estoque é reposto na hora.
- **Estoque**: produtos com custo, preço, taxa e lucro por unidade, e aviso de estoque mínimo.
- **Contas a pagar**: boletos com vencimento, alertas de "vence em X dias" e "vencido", e um botão para marcar como pago.
- **Precificação**: preço sugerido pela margem desejada, preço mínimo, tabela de preços por margem, imposto sobre a venda e aviso quando vender no topo de uma faixa mais barata rende mais.
- **Fotos com IA**: remove o fundo com um modelo de IA que roda no navegador, corrige luz e contraste sem redesenhar o produto, aplica fundo branco quadrado (1000×1000 para a Shopee) e sombra suave. As fotos não são enviadas a nenhum servidor. Usa a biblioteca [@imgly/background-removal](https://github.com/imgly/background-removal-js) (licença AGPL; este repositório é público, o que atende à licença).
- **Taxas**: faixas da Shopee para vendedor CNPJ (2026), editáveis:

| Preço do item | Comissão | Fixa por item |
|---|---|---|
| Abaixo de R$ 9,00 | 20% | metade do preço |
| Até R$ 79,99 | 20% | R$ 4,50 |
| R$ 80,00 a R$ 99,99 | 14% | R$ 16,00 |
| R$ 100,00 a R$ 199,99 | 14% | R$ 20,00 |
| R$ 200,00 a R$ 499,99 | 14% | R$ 26,00 |
| Acima de R$ 500,00 | 14% | R$ 26,00 |

## Situação atual

- **Site:** https://vendas02jcngourmet-hue.github.io/EliderSystem/
- **Banco:** projeto Supabase **jcn gourmet**, tabelas com prefixo `esys_` (`esys_produtos`, `esys_vendas`, `esys_boletos`, `esys_ajustes`), separadas das tabelas do outro sistema que já usa esse projeto.
- **Acesso:** entre com um usuário do Supabase Auth desse projeto. Cada usuário só vê os próprios dados.

## Instalação do zero (caso precise recriar em outro projeto)

### 1. Criar o banco no Supabase

1. Entre em <https://supabase.com> e crie um projeto (o plano gratuito serve). Na região, escolha **South America (São Paulo)**.
2. No menu do projeto, abra **SQL Editor** e clique em **New query**.
3. Cole todo o conteúdo de [`supabase/schema.sql`](supabase/schema.sql) e clique em **Run**.

Isso cria as tabelas `produtos`, `vendas`, `boletos` e `ajustes`, as regras de segurança (cada usuário só vê os próprios dados) e a baixa automática do estoque.

### 2. Criar o seu usuário de acesso

1. No Supabase, vá em **Authentication > Users > Add user > Create new user**.
2. Informe seu e-mail e uma senha forte. Marque **Auto Confirm User**.
3. Para ninguém mais conseguir criar conta: **Authentication > Sign In / Providers > Email** e desligue **Allow new users to sign up**.

### 3. Ligar o site ao banco

1. No Supabase, abra **Project Settings > API** (ou o botão **Connect**).
2. Copie a **Project URL** e a chave **anon public** (também pode aparecer como *publishable key*).
3. Aqui no GitHub, abra o arquivo [`config.js`](config.js), clique no lápis, cole os dois valores e salve com **Commit changes**.

> A chave *anon* pode ficar pública: quem protege os dados é o login e as regras de segurança.
> **Nunca** coloque a chave `service_role` / *secret* no `config.js`.

### 4. Publicar o site no GitHub Pages

1. No repositório, vá em **Settings > Pages**.
2. Em **Source**, escolha **Deploy from a branch**, branch **main**, pasta **/ (root)**, e clique em **Save**.
3. Em um ou dois minutos o site fica disponível em:
   `https://vendas02jcngourmet-hue.github.io/EliderSystem/`

Abra o endereço, entre com o e-mail e a senha do passo 2, e pronto.

## Estrutura

```
index.html            o sistema (telas e cálculos)
config.js             URL e chave pública do Supabase
supabase/schema.sql   tabelas, segurança e gatilho de estoque
```

## Próximos passos

- Importar a planilha de pedidos exportada do UpSeller (o banco já impede pedido duplicado por número + produto).
