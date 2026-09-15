-- =============================================================
-- Schema do banco rh_empresa
-- Projeto de portfolio: modelagem de RH com historico de carreira
-- =============================================================

CREATE DATABASE IF NOT EXISTS rh_empresa;
USE rh_empresa;

-- -------------------------------------------------------------
-- Tabela: departamentos
-- Nao depende de nenhuma outra tabela.
-- -------------------------------------------------------------
CREATE TABLE departamentos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE,
    data_criacao DATE NOT NULL
);

-- -------------------------------------------------------------
-- Tabela: cargos
-- Cada cargo pertence a um departamento.
-- -------------------------------------------------------------
CREATE TABLE cargos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(80) NOT NULL,
    departamento_id INT NOT NULL,
    salario_min DECIMAL(10,2) NOT NULL,
    salario_max DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (departamento_id) REFERENCES departamentos(id),
    CHECK (salario_max >= salario_min)
);

-- -------------------------------------------------------------
-- Tabela: funcionarios
-- gerente_id e um auto-relacionamento: aponta para outro
-- registro dentro da propria tabela funcionarios.
-- -------------------------------------------------------------
CREATE TABLE funcionarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    data_nascimento DATE NOT NULL,
    data_contratacao DATE NOT NULL,
    cargo_id INT NOT NULL,
    gerente_id INT,
    status ENUM('ativo', 'inativo') NOT NULL DEFAULT 'ativo',
    FOREIGN KEY (cargo_id) REFERENCES cargos(id),
    FOREIGN KEY (gerente_id) REFERENCES funcionarios(id)
);

-- -------------------------------------------------------------
-- Tabela: historico_cargos
-- Registra toda a trajetoria de cada funcionario: contratacao,
-- promocoes, transferencias e desligamento.
-- data_fim = NULL significa que aquele e o cargo/periodo atual.
-- -------------------------------------------------------------
CREATE TABLE historico_cargos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    funcionario_id INT NOT NULL,
    cargo_id INT NOT NULL,
    salario DECIMAL(10,2) NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE,
    motivo ENUM('contratacao', 'promocao', 'transferencia', 'desligamento') NOT NULL,
    FOREIGN KEY (funcionario_id) REFERENCES funcionarios(id),
    FOREIGN KEY (cargo_id) REFERENCES cargos(id)
);
