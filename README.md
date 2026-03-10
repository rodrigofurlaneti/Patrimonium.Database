# 🏢 Sistema de Imobiliária — Banco de Dados MySQL

Modelagem completa de banco de dados relacional para uma imobiliária, cobrindo todos os módulos do negócio: cadastro de imóveis, proprietários, clientes, corretores, contratos de locação e venda, cobranças, vistorias, comissões e auditoria.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Tecnologias](#tecnologias)
- [Como Executar](#como-executar)
- [Estrutura do Banco](#estrutura-do-banco)
- [Módulos do Sistema](#módulos-do-sistema)
- [Regras de Negócio](#regras-de-negócio)
- [Triggers](#triggers)
- [Views](#views)
- [Event Scheduler](#event-scheduler)
- [Dados Iniciais (Seed)](#dados-iniciais-seed)
- [Índices de Performance](#índices-de-performance)
- [Diagrama de Entidades](#diagrama-de-entidades)
- [Boas Práticas Adotadas](#boas-práticas-adotadas)

---

## Visão Geral

Este projeto entrega um schema MySQL production-ready para gestão completa de uma imobiliária, contemplando:

- Cadastro de **imóveis** com características, fotos, documentos e histórico de preços
- Gestão de **pessoas** (Física e Jurídica): proprietários, clientes, corretores e fiadores
- Fluxo completo de **locação**: proposta → contrato → cobranças → vistoria → rescisão
- Fluxo completo de **venda**: proposta → contrato → parcelas → escritura → registro
- Controle de **comissões** por corretor
- **Chamados de manutenção** com responsabilidade definida
- **Auditoria** de todas as operações
- **Triggers** automatizando mudanças de status
- **Event Scheduler** para cobranças em atraso
- **Views** prontas para relatórios

---

## Tecnologias

| Tecnologia | Versão mínima |
|---|---|
| MySQL | 8.0+ |
| MySQL Event Scheduler | habilitado |
| Charset | utf8mb4 |
| Collation | utf8mb4_unicode_ci |

> ⚠️ O script utiliza recursos como `CHECK constraints` (disponível a partir do MySQL 8.0.16), `JSON columns` e `Events`. Não é compatível com versões anteriores sem adaptações.

---

## Como Executar

### Pré-requisitos

- MySQL Server 8.0 ou superior instalado e em execução
- Usuário com permissões de criação de banco de dados, triggers e events

### Passo a Passo

**1. Clone ou baixe o arquivo SQL**
```bash
# via terminal
mysql -u root -p < imobiliaria_banco_dados.sql
```

**2. Ou execute pelo MySQL Workbench / DBeaver**
```
File → Open SQL Script → imobiliaria_banco_dados.sql → Execute (Ctrl+Shift+Enter)
```

**3. Verificar a criação**
```sql
USE imobiliaria;
SHOW TABLES;
```

**4. Habilitar o Event Scheduler** (caso não esteja ativo)
```sql
SET GLOBAL event_scheduler = ON;

-- Verificar
SHOW VARIABLES LIKE 'event_scheduler';
```

**5. Verificar triggers**
```sql
SHOW TRIGGERS FROM imobiliaria;
```

---

## Estrutura do Banco

```
imobiliaria/
│
├── Tabelas de Domínio (lookup)
│   ├── tipo_imovel
│   ├── tipo_negocio
│   ├── status_imovel
│   ├── status_contrato
│   ├── status_proposta
│   ├── forma_pagamento
│   ├── tipo_pessoa
│   ├── tipo_documento_imovel
│   ├── tipo_vistoria
│   └── motivo_rescisao
│
├── Endereço
│   ├── estado
│   ├── cidade
│   ├── bairro
│   └── endereco
│
├── Pessoas
│   ├── pessoa              ← entidade central (PF e PJ)
│   ├── proprietario
│   ├── cliente
│   ├── corretor
│   ├── fiador
│   └── pessoa_documento
│
├── Imóvel
│   ├── imovel
│   ├── imovel_foto
│   ├── imovel_documento
│   ├── imovel_caracteristica
│   ├── imovel_caracteristica_rel
│   └── imovel_historico_preco
│
├── Comercial
│   ├── visita
│   ├── proposta
│   └── proposta_historico
│
├── Locação
│   ├── contrato_locacao
│   ├── contrato_locacao_fiador
│   ├── contrato_reajuste
│   ├── cobranca
│   ├── vistoria
│   └── vistoria_item
│
├── Venda
│   ├── contrato_venda
│   └── venda_parcela
│
├── Financeiro
│   ├── comissao
│   └── rescisao
│
├── Operacional
│   └── chamado_manutencao
│
└── Sistema
    ├── perfil_acesso
    ├── usuario
    └── auditoria
```

---

## Módulos do Sistema

### 👤 Pessoas

A tabela `pessoa` é a entidade central para todos os envolvidos no sistema. Uma mesma pessoa pode ser simultaneamente cliente, proprietário e fiador — basta ter registros nas respectivas tabelas relacionadas.

| Campo | Regra |
|---|---|
| `tipo_pessoa_id = 1` (Física) | `cpf` e `nome` são obrigatórios |
| `tipo_pessoa_id = 2` (Jurídica) | `cnpj` e `razao_social` são obrigatórios |
| `email` | Obrigatório para todos |
| `cpf` / `cnpj` | Únicos no banco |

---

### 🏠 Imóveis

Cada imóvel pertence a exatamente um proprietário e pode ter um corretor captador associado.

**Ciclo de vida do status:**
```
Disponível → Em Negociação → Alugado / Vendido / Indisponível
                ↓
            Em Reforma → Disponível
```

**Campos calculados automaticamente por trigger:**
- Status muda para `Alugado` ao criar contrato de locação ativo
- Status muda para `Vendido` ao assinar contrato de venda
- Status volta para `Disponível` ao encerrar/rescindir locação

---

### 📋 Contratos de Locação

| Campo | Detalhe |
|---|---|
| `duracao_meses` | Deve ser > 0 |
| `dia_vencimento` | Entre 1 e 28 |
| `indice_reajuste` | IGP-M, IPCA, etc. |
| `tipo_garantia` | Fiador, Caução, Seguro Fiança, Título Capitalização |
| `valor_caucao` | Obrigatório se `tipo_garantia = 'Caução'` |
| `multa_rescisao_pct` | Percentual sobre o saldo |
| `numero_contrato` | Único no banco |

**Regra crítica:** Não pode existir dois contratos de locação com status `Ativo` para o mesmo imóvel simultaneamente (garantido por trigger).

---

### 💰 Cobranças

Geradas mensalmente para cada contrato ativo. Tipos possíveis:

- Aluguel
- Condomínio
- IPTU
- Multa
- Caução Devolução
- Taxa Extra
- Taxa de Vistoria

**Ciclo de status da cobrança:**
```
Aberta → Paga
Aberta → Atrasada (automático via Event diário)
Aberta / Atrasada → Cancelada
```

Ao registrar `data_pagamento`, o status é automaticamente atualizado para `Paga` via trigger.

---

### 🔑 Contratos de Venda

| Campo | Detalhe |
|---|---|
| `valor_entrada` | Deve ser ≥ 0 e ≤ `valor_venda` |
| `comissao_pct` / `valor_comissao` | Registrados no momento da venda |
| `data_assinatura` → `data_escritura` → `data_registro` | Ordem cronológica garantida por CHECK |

---

### 🤝 Comissões

- Vinculada a exatamente um contrato (venda **ou** locação, nunca os dois)
- `valor_comissao` é calculado automaticamente pelo trigger ao inserir
- Fluxo: `Pendente → Aprovada → Paga`

---

### 🔧 Chamados de Manutenção

Permite identificar a responsabilidade de cada conserto:

| Responsabilidade | Exemplo |
|---|---|
| Locatário | Dano causado pelo uso indevido |
| Proprietário | Desgaste natural, estrutura |
| Imobiliária | Itens acordados em contrato |

---

## Regras de Negócio

Implementadas diretamente no banco via `CHECK CONSTRAINTS`, garantindo integridade independente da aplicação:

| Regra | Onde |
|---|---|
| Área construída ≤ área total | `imovel` |
| Suítes ≤ quartos | `imovel` |
| PF: CPF e nome obrigatórios | `pessoa` |
| PJ: CNPJ e razão social obrigatórios | `pessoa` |
| Caução exige valor preenchido | `contrato_locacao` |
| `data_fim > data_inicio` na locação | `contrato_locacao` |
| Vencimento entre dia 1 e 28 | `contrato_locacao` |
| Entrada ≤ valor de venda | `contrato_venda` |
| Escritura ≥ assinatura; Registro ≥ escritura | `contrato_venda` |
| Exatamente 1 contrato por comissão | `comissao` |
| Valor ofertado > 0 | `proposta` |
| Entrada ≤ valor ofertado | `proposta` |
| Nota de visita entre 1 e 5 | `visita` |
| Rescisão vinculada a somente 1 contrato | `rescisao` |

---

## Triggers

| Trigger | Evento | Ação |
|---|---|---|
| `trg_locacao_ativa_imovel` | INSERT em `contrato_locacao` | Imóvel → `Alugado` |
| `trg_venda_ativa_imovel` | UPDATE em `contrato_venda` | Imóvel → `Vendido` ao assinar |
| `trg_locacao_encerrada_imovel` | UPDATE em `contrato_locacao` | Imóvel → `Disponível` ao encerrar |
| `trg_calcula_comissao` | BEFORE INSERT em `comissao` | Calcula `valor_comissao` automaticamente |
| `trg_cobranca_paga` | BEFORE UPDATE em `cobranca` | Status → `Paga` ao preencher `data_pagamento` |
| `trg_proposta_imovel_disponivel` | BEFORE INSERT em `proposta` | Bloqueia proposta em imóvel vendido/indisponível |
| `trg_contrato_locacao_unico` | BEFORE INSERT em `contrato_locacao` | Bloqueia 2º contrato ativo no mesmo imóvel |
| `trg_historico_preco_aluguel` | AFTER UPDATE em `imovel` | Registra histórico ao alterar `valor_aluguel` ou `valor_venda` |

---

## Views

| View | Descrição |
|---|---|
| `vw_imoveis_disponivel_locacao` | Imóveis disponíveis para locação com dados completos |
| `vw_cobrancas_abertas` | Cobranças abertas/atrasadas com dados do locatário e dias em atraso |
| `vw_comissoes_pendentes` | Total de comissões pendentes agrupado por corretor |
| `vw_resumo_imoveis` | Contagem de imóveis por status |

**Exemplo de uso:**
```sql
-- Ver imóveis disponíveis para locação em SP
SELECT * FROM vw_imoveis_disponivel_locacao WHERE cidade = 'São Paulo';

-- Ver cobranças com mais de 30 dias de atraso
SELECT * FROM vw_cobrancas_abertas WHERE dias_atraso > 30;

-- Relatório de comissões a pagar
SELECT * FROM vw_comissoes_pendentes ORDER BY total_valor DESC;
```

---

## Event Scheduler

```sql
-- evt_cobrancas_atrasadas
-- Executa diariamente e marca como 'Atrasada'
-- todas as cobranças 'Aberta' com vencimento anterior a hoje.
```

Para verificar se está ativo:
```sql
SHOW EVENTS FROM imobiliaria;
SHOW VARIABLES LIKE 'event_scheduler';
```

---

## Dados Iniciais (Seed)

O script já insere os seguintes dados de referência:

- **Tipos de imóvel:** Casa, Apartamento, Cobertura, Studio, Kitnet, Sala Comercial, Loja, Galpão, Terreno, Sítio/Chácara
- **Status de imóvel:** Disponível, Alugado, Vendido, Em Negociação, Indisponível, Em Reforma
- **Tipos de negócio:** Venda, Locação, Temporada
- **Formas de pagamento:** Boleto, PIX, Débito Automático, Transferência Bancária, Cheque
- **Características de imóvel:** Piscina, Churrasqueira, Academia, Playground, Salão de Festas, Portaria 24h e mais 9 opções
- **Perfis de acesso:** Admin, Gerente, Corretor, Financeiro, Atendimento
- **Estados:** SP, RJ, MG, RS, PR, SC, BA, GO, DF, ES
- **Motivos de rescisão:** 8 motivos pré-cadastrados

---

## Índices de Performance

Criados nas colunas mais usadas em filtros e JOINs:

```sql
idx_imovel_status        -- Busca por status do imóvel
idx_imovel_tipo          -- Busca por tipo de imóvel
idx_imovel_proprietario  -- Imóveis por proprietário
idx_imovel_corretor      -- Imóveis por corretor
idx_contrato_loc_status  -- Contratos de locação por status
idx_contrato_loc_imovel  -- Contratos por imóvel
idx_cobranca_status      -- Cobranças por status e vencimento
idx_cobranca_contrato    -- Cobranças por contrato e mês
idx_visita_data          -- Visitas por data
idx_proposta_cliente     -- Propostas por cliente
idx_proposta_imovel      -- Propostas por imóvel
idx_pessoa_cpf           -- Busca por CPF
idx_pessoa_cnpj          -- Busca por CNPJ
idx_pessoa_email         -- Busca por e-mail
```

---

## Diagrama de Entidades

```
estado ──< cidade ──< bairro ──< endereco
                                    │
                            ┌───────┴────────┐
                         pessoa           imovel
                        /  │  \          /  │  \
              proprietario │  corretor  /   │   \
                       cliente       fotos docs características
                           │
                      ┌────┴────┐
                   proposta   visita
                      │
              ┌───────┴──────────┐
      contrato_locacao    contrato_venda
          /   │   \               │
    fiadores reajuste cobrança  parcelas
         │
      vistoria ──< vistoria_item
         │
      rescisao       comissao
```

---

## Boas Práticas Adotadas

- **Chaves primárias** sempre `INT UNSIGNED AUTO_INCREMENT`
- **Foreign Keys** com nomes explícitos (`fk_tabela_campo`)
- **CHECK constraints** para todas as regras de validação numérica e lógica
- **UNIQUE constraints** em campos como CPF, CNPJ, CRECI, número de contrato
- **Soft delete** com coluna `ativo` em vez de DELETE físico nas entidades principais
- **Auditoria de datas** com `criado_em` e `atualizado_em` usando `ON UPDATE CURRENT_TIMESTAMP`
- **Charset utf8mb4** para suporte completo a Unicode (emojis, acentos, etc.)
- **Separação clara** entre domínio (lookup tables) e entidades transacionais
- **JSON column** na tabela de auditoria para armazenar snapshot antes/depois
- **Views nomeadas** com prefixo `vw_` para fácil identificação
- **Triggers nomeados** com prefixo `trg_` descrevendo a ação
- **Eventos nomeados** com prefixo `evt_`

---

## Licença

Este projeto é de uso livre para fins educacionais e comerciais.

---

> Desenvolvido com modelagem orientada às regras reais do mercado imobiliário brasileiro. 🇧🇷
```
