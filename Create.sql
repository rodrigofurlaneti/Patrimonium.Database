-- ============================================================
--  SISTEMA DE IMOBILIÁRIA - BANCO DE DADOS COMPLETO (MySQL)
--  Modelagem com todas as regras de negócio
-- ============================================================

CREATE DATABASE IF NOT EXISTS imobiliaria
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE imobiliaria;

-- ============================================================
-- TABELAS DE DOMÍNIO / ENUMERAÇÕES
-- ============================================================

CREATE TABLE tipo_imovel (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL UNIQUE  -- Casa, Apartamento, Sala Comercial, Terreno, Galpão, etc.
);

CREATE TABLE tipo_negocio (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(30) NOT NULL UNIQUE  -- Venda, Locação, Temporada
);

CREATE TABLE status_imovel (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(40) NOT NULL UNIQUE
    -- Disponível, Alugado, Vendido, Em Negociação, Indisponível, Em Reforma
);

CREATE TABLE status_contrato (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(30) NOT NULL UNIQUE
    -- Ativo, Encerrado, Rescindido, Em Renovação, Aguardando Assinatura
);

CREATE TABLE status_proposta (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(30) NOT NULL UNIQUE
    -- Pendente, Aceita, Recusada, Contraoferta, Cancelada
);

CREATE TABLE forma_pagamento (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(40) NOT NULL UNIQUE
    -- Boleto, PIX, Débito Automático, Transferência, Cheque
);

CREATE TABLE tipo_pessoa (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(20) NOT NULL UNIQUE  -- Física, Jurídica
);

CREATE TABLE tipo_documento_imovel (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(60) NOT NULL UNIQUE
    -- Escritura, Matrícula, IPTU, Habite-se, ART, Planta, Fotos, etc.
);

CREATE TABLE tipo_vistoria (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(30) NOT NULL UNIQUE  -- Entrada, Saída, Periódica
);

CREATE TABLE motivo_rescisao (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(80) NOT NULL UNIQUE
);

-- ============================================================
-- ENDEREÇOS
-- ============================================================

CREATE TABLE estado (
    id  CHAR(2) PRIMARY KEY,          -- UF
    nome VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE cidade (
    id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome     VARCHAR(80)  NOT NULL,
    estado   CHAR(2)      NOT NULL,
    CONSTRAINT fk_cidade_estado FOREIGN KEY (estado) REFERENCES estado(id),
    UNIQUE KEY uq_cidade_estado (nome, estado)
);

CREATE TABLE bairro (
    id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome      VARCHAR(80)  NOT NULL,
    cidade_id INT UNSIGNED NOT NULL,
    CONSTRAINT fk_bairro_cidade FOREIGN KEY (cidade_id) REFERENCES cidade(id),
    UNIQUE KEY uq_bairro_cidade (nome, cidade_id)
);

CREATE TABLE endereco (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    logradouro   VARCHAR(120) NOT NULL,
    numero       VARCHAR(10),
    complemento  VARCHAR(60),
    cep          CHAR(8)      NOT NULL,
    bairro_id    INT UNSIGNED NOT NULL,
    CONSTRAINT fk_endereco_bairro FOREIGN KEY (bairro_id) REFERENCES bairro(id)
);

-- ============================================================
-- PESSOAS (Física e Jurídica)
-- ============================================================

CREATE TABLE pessoa (
    id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_pessoa_id   TINYINT UNSIGNED NOT NULL,
    -- Pessoa Física
    nome             VARCHAR(120),
    cpf              CHAR(11)  UNIQUE,
    rg               VARCHAR(20),
    orgao_emissor    VARCHAR(20),
    data_nascimento  DATE,
    -- Pessoa Jurídica
    razao_social     VARCHAR(120),
    cnpj             CHAR(14) UNIQUE,
    nome_fantasia    VARCHAR(120),
    inscricao_estadual VARCHAR(20),
    -- Contato
    email            VARCHAR(120) NOT NULL,
    telefone         VARCHAR(15),
    celular          VARCHAR(15),
    -- Endereço
    endereco_id      INT UNSIGNED,
    -- Controle
    ativo            TINYINT(1) NOT NULL DEFAULT 1,
    criado_em        DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em    DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_pessoa_tipo        FOREIGN KEY (tipo_pessoa_id) REFERENCES tipo_pessoa(id),
    CONSTRAINT fk_pessoa_endereco    FOREIGN KEY (endereco_id)    REFERENCES endereco(id),

    -- Regra: PF deve ter CPF; PJ deve ter CNPJ
    CONSTRAINT chk_pessoa_pf  CHECK (tipo_pessoa_id <> 1 OR (cpf IS NOT NULL AND nome IS NOT NULL)),
    CONSTRAINT chk_pessoa_pj  CHECK (tipo_pessoa_id <> 2 OR (cnpj IS NOT NULL AND razao_social IS NOT NULL))
);

-- ============================================================
-- CORRETORES
-- ============================================================

CREATE TABLE corretor (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id   INT UNSIGNED NOT NULL UNIQUE,
    creci       VARCHAR(20)  NOT NULL UNIQUE,
    data_admissao DATE       NOT NULL,
    data_demissao DATE,
    comissao_venda_pct   DECIMAL(5,2) NOT NULL DEFAULT 6.00,  -- % padrão sobre venda
    comissao_locacao_pct DECIMAL(5,2) NOT NULL DEFAULT 100.00, -- % de 1 aluguel
    ativo       TINYINT(1)   NOT NULL DEFAULT 1,
    criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_corretor_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id),
    CONSTRAINT chk_comissao_venda   CHECK (comissao_venda_pct   BETWEEN 0 AND 20),
    CONSTRAINT chk_comissao_locacao CHECK (comissao_locacao_pct BETWEEN 0 AND 200)
);

-- ============================================================
-- PROPRIETÁRIOS (um proprietário pode ter vários imóveis)
-- ============================================================

CREATE TABLE proprietario (
    id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id INT UNSIGNED NOT NULL UNIQUE,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_proprietario_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id)
);

-- ============================================================
-- IMÓVEIS
-- ============================================================

CREATE TABLE imovel (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    proprietario_id     INT UNSIGNED     NOT NULL,
    corretor_id         INT UNSIGNED,                   -- corretor captador
    tipo_imovel_id      TINYINT UNSIGNED NOT NULL,
    status_imovel_id    TINYINT UNSIGNED NOT NULL,
    endereco_id         INT UNSIGNED     NOT NULL,
    -- Características
    area_total_m2       DECIMAL(10,2),
    area_construida_m2  DECIMAL(10,2),
    quartos             TINYINT UNSIGNED DEFAULT 0,
    suites              TINYINT UNSIGNED DEFAULT 0,
    banheiros           TINYINT UNSIGNED DEFAULT 0,
    vagas_garagem       TINYINT UNSIGNED DEFAULT 0,
    andar               SMALLINT,
    total_andares       SMALLINT,
    aceita_animais      TINYINT(1) NOT NULL DEFAULT 0,
    mobiliado           TINYINT(1) NOT NULL DEFAULT 0,
    -- Financeiro
    valor_venda         DECIMAL(14,2),
    valor_aluguel       DECIMAL(12,2),
    valor_condominio    DECIMAL(10,2),
    valor_iptu_anual    DECIMAL(10,2),
    -- Descrição
    titulo              VARCHAR(120) NOT NULL,
    descricao           TEXT,
    codigo_interno      VARCHAR(20)  NOT NULL UNIQUE,
    -- Controle
    data_captacao       DATE         NOT NULL,
    ativo               TINYINT(1)   NOT NULL DEFAULT 1,
    criado_em           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_imovel_proprietario  FOREIGN KEY (proprietario_id)  REFERENCES proprietario(id),
    CONSTRAINT fk_imovel_corretor      FOREIGN KEY (corretor_id)      REFERENCES corretor(id),
    CONSTRAINT fk_imovel_tipo          FOREIGN KEY (tipo_imovel_id)   REFERENCES tipo_imovel(id),
    CONSTRAINT fk_imovel_status        FOREIGN KEY (status_imovel_id) REFERENCES status_imovel(id),
    CONSTRAINT fk_imovel_endereco      FOREIGN KEY (endereco_id)      REFERENCES endereco(id),

    -- Regra: área construída não pode ser maior que área total
    CONSTRAINT chk_area CHECK (area_construida_m2 IS NULL OR area_total_m2 IS NULL OR area_construida_m2 <= area_total_m2),
    -- Regra: suítes não podem ser mais que quartos
    CONSTRAINT chk_suites CHECK (suites <= quartos)
);

-- Características extras (piscina, churrasqueira, academia, etc.)
CREATE TABLE imovel_caracteristica (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao   VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE imovel_caracteristica_rel (
    imovel_id         INT UNSIGNED NOT NULL,
    caracteristica_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (imovel_id, caracteristica_id),
    CONSTRAINT fk_icr_imovel FOREIGN KEY (imovel_id) REFERENCES imovel(id) ON DELETE CASCADE,
    CONSTRAINT fk_icr_caract FOREIGN KEY (caracteristica_id) REFERENCES imovel_caracteristica(id)
);

-- Documentos do imóvel
CREATE TABLE imovel_documento (
    id                      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id               INT UNSIGNED     NOT NULL,
    tipo_documento_id       TINYINT UNSIGNED NOT NULL,
    descricao               VARCHAR(120),
    url_arquivo             VARCHAR(255),
    data_emissao            DATE,
    data_vencimento         DATE,
    criado_em               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_idoc_imovel FOREIGN KEY (imovel_id)         REFERENCES imovel(id) ON DELETE CASCADE,
    CONSTRAINT fk_idoc_tipo   FOREIGN KEY (tipo_documento_id) REFERENCES tipo_documento_imovel(id)
);

-- Fotos do imóvel
CREATE TABLE imovel_foto (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id   INT UNSIGNED NOT NULL,
    url         VARCHAR(255) NOT NULL,
    legenda     VARCHAR(120),
    capa        TINYINT(1)   NOT NULL DEFAULT 0,
    ordem       SMALLINT UNSIGNED DEFAULT 0,
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_foto_imovel FOREIGN KEY (imovel_id) REFERENCES imovel(id) ON DELETE CASCADE
);

-- Histórico de preços
CREATE TABLE imovel_historico_preco (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id       INT UNSIGNED NOT NULL,
    tipo_negocio_id TINYINT UNSIGNED NOT NULL,
    valor_anterior  DECIMAL(14,2) NOT NULL,
    valor_novo      DECIMAL(14,2) NOT NULL,
    motivo          VARCHAR(120),
    alterado_em     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alterado_por    INT UNSIGNED,   -- pessoa_id do usuário
    CONSTRAINT fk_ihp_imovel   FOREIGN KEY (imovel_id)       REFERENCES imovel(id),
    CONSTRAINT fk_ihp_negocio  FOREIGN KEY (tipo_negocio_id) REFERENCES tipo_negocio(id)
);

-- ============================================================
-- CLIENTES (interessados / locatários / compradores)
-- ============================================================

CREATE TABLE cliente (
    id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id        INT UNSIGNED NOT NULL UNIQUE,
    renda_mensal     DECIMAL(12,2),
    observacoes      TEXT,
    criado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cliente_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id)
);

-- Fiadores
CREATE TABLE fiador (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED NOT NULL UNIQUE,
    renda_mensal    DECIMAL(12,2),
    imovel_proprio  TINYINT(1) NOT NULL DEFAULT 0,
    observacoes     TEXT,
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fiador_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id)
);

-- Documentos do cliente/fiador
CREATE TABLE pessoa_documento (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id       INT UNSIGNED NOT NULL,
    tipo_doc        VARCHAR(40)  NOT NULL,  -- CPF, RG, Comprovante Renda, etc.
    url_arquivo     VARCHAR(255),
    data_emissao    DATE,
    data_vencimento DATE,
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pdoc_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id)
);

-- ============================================================
-- VISITAS
-- ============================================================

CREATE TABLE visita (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id       INT UNSIGNED NOT NULL,
    cliente_id      INT UNSIGNED NOT NULL,
    corretor_id     INT UNSIGNED NOT NULL,
    data_hora       DATETIME     NOT NULL,
    status          ENUM('Agendada','Realizada','Cancelada','Cliente Não Compareceu') NOT NULL DEFAULT 'Agendada',
    feedback        TEXT,
    nota_cliente    TINYINT UNSIGNED,   -- 1 a 5
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_visita_imovel   FOREIGN KEY (imovel_id)   REFERENCES imovel(id),
    CONSTRAINT fk_visita_cliente  FOREIGN KEY (cliente_id)  REFERENCES cliente(id),
    CONSTRAINT fk_visita_corretor FOREIGN KEY (corretor_id) REFERENCES corretor(id),
    CONSTRAINT chk_nota CHECK (nota_cliente IS NULL OR nota_cliente BETWEEN 1 AND 5)
);

-- ============================================================
-- PROPOSTAS
-- ============================================================

CREATE TABLE proposta (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id           INT UNSIGNED     NOT NULL,
    cliente_id          INT UNSIGNED     NOT NULL,
    corretor_id         INT UNSIGNED     NOT NULL,
    tipo_negocio_id     TINYINT UNSIGNED NOT NULL,
    status_proposta_id  TINYINT UNSIGNED NOT NULL,
    valor_ofertado      DECIMAL(14,2)    NOT NULL,
    valor_entrada       DECIMAL(14,2),
    num_parcelas        SMALLINT UNSIGNED,
    forma_pagamento_id  TINYINT UNSIGNED,
    observacoes         TEXT,
    validade_ate        DATE             NOT NULL,
    criado_em           DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_prop_imovel    FOREIGN KEY (imovel_id)          REFERENCES imovel(id),
    CONSTRAINT fk_prop_cliente   FOREIGN KEY (cliente_id)         REFERENCES cliente(id),
    CONSTRAINT fk_prop_corretor  FOREIGN KEY (corretor_id)        REFERENCES corretor(id),
    CONSTRAINT fk_prop_negocio   FOREIGN KEY (tipo_negocio_id)    REFERENCES tipo_negocio(id),
    CONSTRAINT fk_prop_status    FOREIGN KEY (status_proposta_id) REFERENCES status_proposta(id),
    CONSTRAINT fk_prop_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES forma_pagamento(id),

    -- Regra: valor ofertado deve ser positivo
    CONSTRAINT chk_valor_ofertado CHECK (valor_ofertado > 0),
    -- Regra: entrada não pode ser maior que valor ofertado
    CONSTRAINT chk_entrada CHECK (valor_entrada IS NULL OR valor_entrada <= valor_ofertado)
);

-- Histórico de status das propostas (auditoria)
CREATE TABLE proposta_historico (
    id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    proposta_id        INT UNSIGNED     NOT NULL,
    status_anterior_id TINYINT UNSIGNED,
    status_novo_id     TINYINT UNSIGNED NOT NULL,
    observacao         TEXT,
    alterado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alterado_por       INT UNSIGNED,
    CONSTRAINT fk_phist_proposta FOREIGN KEY (proposta_id) REFERENCES proposta(id)
);

-- ============================================================
-- CONTRATOS DE LOCAÇÃO
-- ============================================================

CREATE TABLE contrato_locacao (
    id                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id            INT UNSIGNED     NOT NULL,
    locatario_id         INT UNSIGNED     NOT NULL,  -- cliente
    corretor_id          INT UNSIGNED     NOT NULL,
    status_contrato_id   TINYINT UNSIGNED NOT NULL,
    forma_pagamento_id   TINYINT UNSIGNED NOT NULL,
    -- Período
    data_inicio          DATE             NOT NULL,
    data_fim             DATE             NOT NULL,
    duracao_meses        TINYINT UNSIGNED NOT NULL,
    -- Financeiro
    valor_aluguel        DECIMAL(12,2)    NOT NULL,
    valor_condominio     DECIMAL(10,2)    DEFAULT 0,
    valor_iptu_mensal    DECIMAL(10,2)    DEFAULT 0,
    dia_vencimento       TINYINT UNSIGNED NOT NULL DEFAULT 10,  -- dia do mês
    indice_reajuste      VARCHAR(20)      NOT NULL DEFAULT 'IGPM',  -- IGP-M, IPCA, etc.
    multa_rescisao_pct   DECIMAL(5,2)     NOT NULL DEFAULT 10.00,
    -- Garantia
    tipo_garantia        ENUM('Fiador','Caução','Seguro Fiança','Título Capitalização','Sem Garantia') NOT NULL,
    valor_caucao         DECIMAL(12,2),   -- 3x aluguel normalmente
    -- Controle
    numero_contrato      VARCHAR(30)      NOT NULL UNIQUE,
    observacoes          TEXT,
    criado_em            DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cl_imovel    FOREIGN KEY (imovel_id)           REFERENCES imovel(id),
    CONSTRAINT fk_cl_locatario FOREIGN KEY (locatario_id)        REFERENCES cliente(id),
    CONSTRAINT fk_cl_corretor  FOREIGN KEY (corretor_id)         REFERENCES corretor(id),
    CONSTRAINT fk_cl_status    FOREIGN KEY (status_contrato_id)  REFERENCES status_contrato(id),
    CONSTRAINT fk_cl_pagamento FOREIGN KEY (forma_pagamento_id)  REFERENCES forma_pagamento(id),

    -- Regra: data_fim deve ser posterior a data_inicio
    CONSTRAINT chk_datas_locacao  CHECK (data_fim > data_inicio),
    -- Regra: vencimento entre dia 1 e 28
    CONSTRAINT chk_vencimento     CHECK (dia_vencimento BETWEEN 1 AND 28),
    -- Regra: duração coerente
    CONSTRAINT chk_duracao        CHECK (duracao_meses > 0),
    -- Regra: caução necessária se tipo for caução
    CONSTRAINT chk_caucao         CHECK (tipo_garantia <> 'Caução' OR valor_caucao IS NOT NULL)
);

-- Fiadores do contrato de locação (pode ser mais de um)
CREATE TABLE contrato_locacao_fiador (
    contrato_id INT UNSIGNED NOT NULL,
    fiador_id   INT UNSIGNED NOT NULL,
    PRIMARY KEY (contrato_id, fiador_id),
    CONSTRAINT fk_clf_contrato FOREIGN KEY (contrato_id) REFERENCES contrato_locacao(id),
    CONSTRAINT fk_clf_fiador   FOREIGN KEY (fiador_id)   REFERENCES fiador(id)
);

-- Reajustes de aluguel
CREATE TABLE contrato_reajuste (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    contrato_id     INT UNSIGNED  NOT NULL,
    data_reajuste   DATE          NOT NULL,
    valor_anterior  DECIMAL(12,2) NOT NULL,
    valor_novo      DECIMAL(12,2) NOT NULL,
    indice_aplicado VARCHAR(20)   NOT NULL,
    percentual      DECIMAL(6,3)  NOT NULL,
    observacao      VARCHAR(120),
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cr_contrato FOREIGN KEY (contrato_id) REFERENCES contrato_locacao(id),
    CONSTRAINT chk_reajuste_positivo CHECK (percentual > -50)
);

-- ============================================================
-- COBRANÇAS / PARCELAS DE LOCAÇÃO
-- ============================================================

CREATE TABLE cobranca (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    contrato_id         INT UNSIGNED     NOT NULL,
    tipo                ENUM('Aluguel','Condomínio','IPTU','Multa','Caução Devolução',
                             'Taxa Extra','Taxa de Vistoria') NOT NULL,
    mes_referencia      DATE             NOT NULL,  -- primeiro dia do mês de referência
    valor               DECIMAL(12,2)    NOT NULL,
    valor_multa         DECIMAL(10,2)    DEFAULT 0,
    valor_juros         DECIMAL(10,2)    DEFAULT 0,
    valor_desconto      DECIMAL(10,2)    DEFAULT 0,
    vencimento          DATE             NOT NULL,
    data_pagamento      DATE,
    status              ENUM('Aberta','Paga','Atrasada','Cancelada') NOT NULL DEFAULT 'Aberta',
    forma_pagamento_id  TINYINT UNSIGNED,
    observacoes         VARCHAR(255),
    criado_em           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cob_contrato  FOREIGN KEY (contrato_id)       REFERENCES contrato_locacao(id),
    CONSTRAINT fk_cob_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES forma_pagamento(id),
    CONSTRAINT chk_valor_cob CHECK (valor > 0)
);

-- ============================================================
-- VISTORIAS
-- ============================================================

CREATE TABLE vistoria (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id       INT UNSIGNED     NOT NULL,
    contrato_id     INT UNSIGNED,               -- NULL para vistoria avulsa
    tipo_vistoria_id TINYINT UNSIGNED NOT NULL,
    vistoriador     VARCHAR(120)     NOT NULL,
    data_vistoria   DATE             NOT NULL,
    laudo_url       VARCHAR(255),
    observacoes     TEXT,
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_vist_imovel    FOREIGN KEY (imovel_id)        REFERENCES imovel(id),
    CONSTRAINT fk_vist_contrato  FOREIGN KEY (contrato_id)      REFERENCES contrato_locacao(id),
    CONSTRAINT fk_vist_tipo      FOREIGN KEY (tipo_vistoria_id) REFERENCES tipo_vistoria(id)
);

CREATE TABLE vistoria_item (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vistoria_id     INT UNSIGNED NOT NULL,
    ambiente        VARCHAR(60)  NOT NULL,   -- Sala, Quarto 1, Cozinha, etc.
    item            VARCHAR(80)  NOT NULL,   -- Parede, Piso, Janela, Torneira...
    estado          ENUM('Ótimo','Bom','Regular','Ruim','Péssimo') NOT NULL,
    observacao      VARCHAR(255),
    foto_url        VARCHAR(255),
    CONSTRAINT fk_vi_vistoria FOREIGN KEY (vistoria_id) REFERENCES vistoria(id) ON DELETE CASCADE
);

-- ============================================================
-- CONTRATOS DE VENDA
-- ============================================================

CREATE TABLE contrato_venda (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id           INT UNSIGNED     NOT NULL,
    comprador_id        INT UNSIGNED     NOT NULL,
    corretor_id         INT UNSIGNED     NOT NULL,
    status_contrato_id  TINYINT UNSIGNED NOT NULL,
    -- Financeiro
    valor_venda         DECIMAL(14,2)    NOT NULL,
    valor_entrada       DECIMAL(14,2)    NOT NULL DEFAULT 0,
    num_parcelas        SMALLINT UNSIGNED,
    forma_pagamento_id  TINYINT UNSIGNED NOT NULL,
    banco_financiamento VARCHAR(80),
    -- Documentação
    numero_contrato     VARCHAR(30)      NOT NULL UNIQUE,
    data_assinatura     DATE,
    data_escritura      DATE,
    data_registro       DATE,
    cartorio            VARCHAR(120),
    -- Comissão
    comissao_pct        DECIMAL(5,2)     NOT NULL,
    valor_comissao      DECIMAL(12,2)    NOT NULL,
    -- Controle
    observacoes         TEXT,
    criado_em           DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cv_imovel    FOREIGN KEY (imovel_id)          REFERENCES imovel(id),
    CONSTRAINT fk_cv_comprador FOREIGN KEY (comprador_id)       REFERENCES cliente(id),
    CONSTRAINT fk_cv_corretor  FOREIGN KEY (corretor_id)        REFERENCES corretor(id),
    CONSTRAINT fk_cv_status    FOREIGN KEY (status_contrato_id) REFERENCES status_contrato(id),
    CONSTRAINT fk_cv_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES forma_pagamento(id),

    CONSTRAINT chk_valor_venda   CHECK (valor_venda > 0),
    CONSTRAINT chk_entrada_venda CHECK (valor_entrada >= 0 AND valor_entrada <= valor_venda),
    CONSTRAINT chk_escritura     CHECK (data_escritura IS NULL OR data_assinatura IS NULL OR data_escritura >= data_assinatura),
    CONSTRAINT chk_registro      CHECK (data_registro  IS NULL OR data_escritura  IS NULL OR data_registro  >= data_escritura)
);

-- Parcelas de venda (financiamento próprio)
CREATE TABLE venda_parcela (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    contrato_id     INT UNSIGNED     NOT NULL,
    numero          SMALLINT UNSIGNED NOT NULL,
    vencimento      DATE             NOT NULL,
    valor           DECIMAL(12,2)    NOT NULL,
    data_pagamento  DATE,
    status          ENUM('Aberta','Paga','Atrasada','Cancelada') NOT NULL DEFAULT 'Aberta',
    CONSTRAINT fk_vp_contrato FOREIGN KEY (contrato_id) REFERENCES contrato_venda(id),
    UNIQUE KEY uq_parcela (contrato_id, numero)
);

-- ============================================================
-- COMISSÕES DOS CORRETORES
-- ============================================================

CREATE TABLE comissao (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    corretor_id     INT UNSIGNED     NOT NULL,
    tipo_negocio_id TINYINT UNSIGNED NOT NULL,
    -- Referência ao contrato (somente um dos dois)
    contrato_venda_id   INT UNSIGNED,
    contrato_locacao_id INT UNSIGNED,
    valor_base      DECIMAL(14,2)    NOT NULL,
    percentual      DECIMAL(5,2)     NOT NULL,
    valor_comissao  DECIMAL(12,2)    NOT NULL,
    status          ENUM('Pendente','Aprovada','Paga','Cancelada') NOT NULL DEFAULT 'Pendente',
    data_pagamento  DATE,
    observacoes     TEXT,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_com_corretor  FOREIGN KEY (corretor_id)          REFERENCES corretor(id),
    CONSTRAINT fk_com_negocio   FOREIGN KEY (tipo_negocio_id)      REFERENCES tipo_negocio(id),
    CONSTRAINT fk_com_venda     FOREIGN KEY (contrato_venda_id)    REFERENCES contrato_venda(id),
    CONSTRAINT fk_com_locacao   FOREIGN KEY (contrato_locacao_id)  REFERENCES contrato_locacao(id),

    -- Regra: exatamente um contrato deve estar preenchido
    CONSTRAINT chk_contrato_comissao CHECK (
        (contrato_venda_id IS NOT NULL AND contrato_locacao_id IS NULL) OR
        (contrato_venda_id IS NULL AND contrato_locacao_id IS NOT NULL)
    ),
    CONSTRAINT chk_valor_comissao CHECK (valor_comissao >= 0)
);

-- ============================================================
-- RESCISÕES DE CONTRATO
-- ============================================================

CREATE TABLE rescisao (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    motivo_id           INT UNSIGNED NOT NULL,
    -- Somente um dos dois
    contrato_locacao_id INT UNSIGNED,
    contrato_venda_id   INT UNSIGNED,
    data_solicitacao    DATE         NOT NULL,
    data_efetiva        DATE         NOT NULL,
    valor_multa         DECIMAL(12,2) DEFAULT 0,
    valor_devolucao     DECIMAL(12,2) DEFAULT 0,
    descricao           TEXT,
    criado_em           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_resc_motivo   FOREIGN KEY (motivo_id)            REFERENCES motivo_rescisao(id),
    CONSTRAINT fk_resc_locacao  FOREIGN KEY (contrato_locacao_id)  REFERENCES contrato_locacao(id),
    CONSTRAINT fk_resc_venda    FOREIGN KEY (contrato_venda_id)    REFERENCES contrato_venda(id),

    CONSTRAINT chk_resc_contrato CHECK (
        (contrato_locacao_id IS NOT NULL AND contrato_venda_id IS NULL) OR
        (contrato_locacao_id IS NULL AND contrato_venda_id IS NOT NULL)
    ),
    CONSTRAINT chk_data_efetiva CHECK (data_efetiva >= data_solicitacao)
);

-- ============================================================
-- MANUTENÇÃO / CHAMADOS
-- ============================================================

CREATE TABLE chamado_manutencao (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    imovel_id       INT UNSIGNED NOT NULL,
    contrato_id     INT UNSIGNED,
    solicitante_id  INT UNSIGNED NOT NULL,  -- pessoa_id
    descricao       TEXT         NOT NULL,
    prioridade      ENUM('Baixa','Média','Alta','Urgente') NOT NULL DEFAULT 'Média',
    status          ENUM('Aberto','Em Andamento','Aguardando Material','Concluído','Cancelado') NOT NULL DEFAULT 'Aberto',
    responsabilidade ENUM('Locatário','Proprietário','Imobiliária') NOT NULL,
    data_abertura   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_conclusao  DATETIME,
    valor_servico   DECIMAL(10,2),
    observacoes     TEXT,

    CONSTRAINT fk_chm_imovel      FOREIGN KEY (imovel_id)    REFERENCES imovel(id),
    CONSTRAINT fk_chm_contrato    FOREIGN KEY (contrato_id)  REFERENCES contrato_locacao(id),
    CONSTRAINT fk_chm_solicitante FOREIGN KEY (solicitante_id) REFERENCES pessoa(id)
);

-- ============================================================
-- USUÁRIOS DO SISTEMA (Backoffice)
-- ============================================================

CREATE TABLE perfil_acesso (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome      VARCHAR(40) NOT NULL UNIQUE  -- Admin, Gerente, Corretor, Financeiro, Atendimento
);

CREATE TABLE usuario (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pessoa_id   INT UNSIGNED     NOT NULL UNIQUE,
    perfil_id   TINYINT UNSIGNED NOT NULL,
    login       VARCHAR(60)      NOT NULL UNIQUE,
    senha_hash  VARCHAR(255)     NOT NULL,
    ativo       TINYINT(1)       NOT NULL DEFAULT 1,
    ultimo_acesso DATETIME,
    criado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_usr_pessoa FOREIGN KEY (pessoa_id) REFERENCES pessoa(id),
    CONSTRAINT fk_usr_perfil FOREIGN KEY (perfil_id) REFERENCES perfil_acesso(id)
);

-- Log de auditoria geral
CREATE TABLE auditoria (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id  INT UNSIGNED,
    tabela      VARCHAR(60)  NOT NULL,
    operacao    ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    registro_id INT UNSIGNED NOT NULL,
    dados_antes JSON,
    dados_depois JSON,
    ip          VARCHAR(45),
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_aud_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);

-- ============================================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================================

CREATE INDEX idx_imovel_status      ON imovel(status_imovel_id);
CREATE INDEX idx_imovel_tipo        ON imovel(tipo_imovel_id);
CREATE INDEX idx_imovel_proprietario ON imovel(proprietario_id);
CREATE INDEX idx_imovel_corretor    ON imovel(corretor_id);
CREATE INDEX idx_contrato_loc_status ON contrato_locacao(status_contrato_id);
CREATE INDEX idx_contrato_loc_imovel ON contrato_locacao(imovel_id);
CREATE INDEX idx_cobranca_status    ON cobranca(status, vencimento);
CREATE INDEX idx_cobranca_contrato  ON cobranca(contrato_id, mes_referencia);
CREATE INDEX idx_visita_data        ON visita(data_hora);
CREATE INDEX idx_proposta_cliente   ON proposta(cliente_id);
CREATE INDEX idx_proposta_imovel    ON proposta(imovel_id);
CREATE INDEX idx_pessoa_cpf         ON pessoa(cpf);
CREATE INDEX idx_pessoa_cnpj        ON pessoa(cnpj);
CREATE INDEX idx_pessoa_email       ON pessoa(email);

-- ============================================================
-- TRIGGERS - REGRAS DE NEGÓCIO AUTOMÁTICAS
-- ============================================================

DELIMITER $$

-- TRIGGER 1: Ao assinar contrato de locação, mudar status do imóvel para "Alugado"
CREATE TRIGGER trg_locacao_ativa_imovel
AFTER INSERT ON contrato_locacao
FOR EACH ROW
BEGIN
    UPDATE imovel
    SET status_imovel_id = (SELECT id FROM status_imovel WHERE descricao = 'Alugado')
    WHERE id = NEW.imovel_id;
END$$

-- TRIGGER 2: Ao assinar contrato de venda, mudar status do imóvel para "Vendido"
CREATE TRIGGER trg_venda_ativa_imovel
AFTER UPDATE ON contrato_venda
FOR EACH ROW
BEGIN
    IF NEW.data_assinatura IS NOT NULL AND OLD.data_assinatura IS NULL THEN
        UPDATE imovel
        SET status_imovel_id = (SELECT id FROM status_imovel WHERE descricao = 'Vendido')
        WHERE id = NEW.imovel_id;
    END IF;
END$$

-- TRIGGER 3: Ao encerrar contrato de locação, liberar imóvel para "Disponível"
CREATE TRIGGER trg_locacao_encerrada_imovel
AFTER UPDATE ON contrato_locacao
FOR EACH ROW
BEGIN
    IF NEW.status_contrato_id <> OLD.status_contrato_id THEN
        IF (SELECT descricao FROM status_contrato WHERE id = NEW.status_contrato_id)
           IN ('Encerrado','Rescindido') THEN
            UPDATE imovel
            SET status_imovel_id = (SELECT id FROM status_imovel WHERE descricao = 'Disponível')
            WHERE id = NEW.imovel_id;
        END IF;
    END IF;
END$$

-- TRIGGER 4: Calcular valor_comissao automaticamente ao inserir comissão
CREATE TRIGGER trg_calcula_comissao
BEFORE INSERT ON comissao
FOR EACH ROW
BEGIN
    SET NEW.valor_comissao = ROUND(NEW.valor_base * NEW.percentual / 100, 2);
END$$

-- TRIGGER 5: Cobranças em atraso - atualizar status automaticamente
-- (executado por EVENT SCHEDULER abaixo, mas o trigger protege atualização manual)
CREATE TRIGGER trg_cobranca_paga
BEFORE UPDATE ON cobranca
FOR EACH ROW
BEGIN
    IF NEW.data_pagamento IS NOT NULL AND OLD.data_pagamento IS NULL THEN
        SET NEW.status = 'Paga';
    END IF;
END$$

-- TRIGGER 6: Impedir proposta em imóvel já vendido ou indisponível
CREATE TRIGGER trg_proposta_imovel_disponivel
BEFORE INSERT ON proposta
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(40);
    SELECT s.descricao INTO v_status
    FROM imovel i
    JOIN status_imovel s ON s.id = i.status_imovel_id
    WHERE i.id = NEW.imovel_id;

    IF v_status IN ('Vendido', 'Indisponível') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível criar proposta para imóvel Vendido ou Indisponível.';
    END IF;
END$$

-- TRIGGER 7: Impedir dois contratos de locação ativos para o mesmo imóvel
CREATE TRIGGER trg_contrato_locacao_unico
BEFORE INSERT ON contrato_locacao
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM contrato_locacao cl
    JOIN status_contrato sc ON sc.id = cl.status_contrato_id
    WHERE cl.imovel_id = NEW.imovel_id
      AND sc.descricao = 'Ativo';

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Já existe um contrato de locação ativo para este imóvel.';
    END IF;
END$$

-- TRIGGER 8: Gravar histórico de preço quando valor_aluguel ou valor_venda mudar
CREATE TRIGGER trg_historico_preco_aluguel
AFTER UPDATE ON imovel
FOR EACH ROW
BEGIN
    IF NEW.valor_aluguel <> OLD.valor_aluguel AND OLD.valor_aluguel IS NOT NULL THEN
        INSERT INTO imovel_historico_preco
            (imovel_id, tipo_negocio_id, valor_anterior, valor_novo, alterado_em)
        VALUES
            (NEW.id, (SELECT id FROM tipo_negocio WHERE descricao = 'Locação'),
             OLD.valor_aluguel, NEW.valor_aluguel, NOW());
    END IF;
    IF NEW.valor_venda <> OLD.valor_venda AND OLD.valor_venda IS NOT NULL THEN
        INSERT INTO imovel_historico_preco
            (imovel_id, tipo_negocio_id, valor_anterior, valor_novo, alterado_em)
        VALUES
            (NEW.id, (SELECT id FROM tipo_negocio WHERE descricao = 'Venda'),
             OLD.valor_venda, NEW.valor_venda, NOW());
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- EVENT SCHEDULER - Cobranças em atraso
-- ============================================================

SET GLOBAL event_scheduler = ON;

DELIMITER $$
CREATE EVENT evt_cobrancas_atrasadas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    UPDATE cobranca
    SET status = 'Atrasada'
    WHERE status = 'Aberta'
      AND vencimento < CURDATE();
END$$
DELIMITER ;

-- ============================================================
-- VIEWS ÚTEIS
-- ============================================================

-- Imóveis disponíveis para locação
CREATE OR REPLACE VIEW vw_imoveis_disponivel_locacao AS
SELECT
    i.id, i.codigo_interno, i.titulo,
    ti.descricao AS tipo,
    i.area_construida_m2, i.quartos, i.suites,
    i.banheiros, i.vagas_garagem,
    i.valor_aluguel, i.valor_condominio,
    CONCAT(e.logradouro,', ',e.numero) AS endereco,
    b.nome AS bairro, c.nome AS cidade
FROM imovel i
JOIN tipo_imovel    ti ON ti.id = i.tipo_imovel_id
JOIN status_imovel  si ON si.id = i.status_imovel_id
JOIN endereco       e  ON e.id  = i.endereco_id
JOIN bairro         b  ON b.id  = e.bairro_id
JOIN cidade         c  ON c.id  = b.cidade_id
WHERE si.descricao = 'Disponível' AND i.valor_aluguel IS NOT NULL AND i.ativo = 1;

-- Cobranças em aberto (locação)
CREATE OR REPLACE VIEW vw_cobrancas_abertas AS
SELECT
    co.id, co.mes_referencia, co.tipo, co.valor,
    co.vencimento, co.status,
    DATEDIFF(CURDATE(), co.vencimento) AS dias_atraso,
    p.nome AS locatario, p.email, p.celular,
    im.codigo_interno, im.titulo
FROM cobranca co
JOIN contrato_locacao cl ON cl.id = co.contrato_id
JOIN cliente          ct ON ct.id = cl.locatario_id
JOIN pessoa           p  ON p.id  = ct.pessoa_id
JOIN imovel           im ON im.id = cl.imovel_id
WHERE co.status IN ('Aberta','Atrasada');

-- Comissões pendentes por corretor
CREATE OR REPLACE VIEW vw_comissoes_pendentes AS
SELECT
    cor.id AS corretor_id,
    p.nome AS corretor,
    cor.creci,
    COUNT(*)               AS total_pendentes,
    SUM(com.valor_comissao) AS total_valor
FROM comissao com
JOIN corretor  cor ON cor.id = com.corretor_id
JOIN pessoa    p   ON p.id   = cor.pessoa_id
WHERE com.status = 'Pendente'
GROUP BY cor.id, p.nome, cor.creci;

-- Resumo de imóveis por status
CREATE OR REPLACE VIEW vw_resumo_imoveis AS
SELECT
    si.descricao AS status,
    COUNT(*) AS total
FROM imovel i
JOIN status_imovel si ON si.id = i.status_imovel_id
WHERE i.ativo = 1
GROUP BY si.descricao;

-- ============================================================
-- DADOS INICIAIS (Seed)
-- ============================================================

INSERT INTO tipo_pessoa   (descricao) VALUES ('Física'), ('Jurídica');
INSERT INTO tipo_negocio  (descricao) VALUES ('Venda'), ('Locação'), ('Temporada');
INSERT INTO status_imovel (descricao) VALUES
    ('Disponível'), ('Alugado'), ('Vendido'),
    ('Em Negociação'), ('Indisponível'), ('Em Reforma');
INSERT INTO status_contrato (descricao) VALUES
    ('Ativo'), ('Encerrado'), ('Rescindido'),
    ('Em Renovação'), ('Aguardando Assinatura');
INSERT INTO status_proposta (descricao) VALUES
    ('Pendente'), ('Aceita'), ('Recusada'), ('Contraoferta'), ('Cancelada');
INSERT INTO forma_pagamento (descricao) VALUES
    ('Boleto'), ('PIX'), ('Débito Automático'), ('Transferência Bancária'), ('Cheque');
INSERT INTO tipo_imovel (descricao) VALUES
    ('Casa'), ('Apartamento'), ('Cobertura'), ('Studio'), ('Kitnet'),
    ('Sala Comercial'), ('Loja'), ('Galpão'), ('Terreno'), ('Sítio/Chácara');
INSERT INTO tipo_documento_imovel (descricao) VALUES
    ('Escritura'), ('Matrícula do Imóvel'), ('IPTU'), ('Habite-se'),
    ('ART / RRT'), ('Planta Baixa'), ('Fotos'), ('Alvará de Funcionamento');
INSERT INTO tipo_vistoria (descricao) VALUES ('Entrada'), ('Saída'), ('Periódica');
INSERT INTO motivo_rescisao (descricao) VALUES
    ('Término do Contrato'), ('Acordo entre as Partes'),
    ('Inadimplência do Locatário'), ('Descumprimento Contratual pelo Locador'),
    ('Venda do Imóvel'), ('Necessidade de Uso pelo Proprietário'),
    ('Desistência do Comprador'), ('Financiamento Negado');
INSERT INTO perfil_acesso (nome) VALUES
    ('Admin'), ('Gerente'), ('Corretor'), ('Financeiro'), ('Atendimento');
INSERT INTO imovel_caracteristica (descricao) VALUES
    ('Piscina'), ('Churrasqueira'), ('Academia'), ('Playground'), ('Salão de Festas'),
    ('Portaria 24h'), ('Câmeras de Segurança'), ('Elevador'), ('Gerador'),
    ('Ar-condicionado'), ('Aquecedor Solar'), ('Varanda Gourmet'), ('Despensa'),
    ('Lavanderia'), ('Home Office');

-- Estados (principais)
INSERT INTO estado VALUES
    ('SP','São Paulo'), ('RJ','Rio de Janeiro'), ('MG','Minas Gerais'),
    ('RS','Rio Grande do Sul'), ('PR','Paraná'), ('SC','Santa Catarina'),
    ('BA','Bahia'), ('GO','Goiás'), ('DF','Distrito Federal'), ('ES','Espírito Santo');

-- ============================================================
-- FIM DO SCRIPT
-- ============================================================
