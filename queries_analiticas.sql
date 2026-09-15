-- =============================================================
-- Queries analiticas - Projeto RH (rh_empresa)
-- =============================================================

-- -------------------------------------------------------------
-- 1. Headcount por departamento (apenas funcionarios ativos)
-- -------------------------------------------------------------
SELECT 
    d.nome AS departamento,
    COUNT(f.id) AS total_funcionarios
FROM departamentos d
JOIN cargos c ON c.departamento_id = d.id
JOIN funcionarios f ON f.cargo_id = c.id
WHERE f.status = 'ativo'
GROUP BY d.nome
ORDER BY total_funcionarios DESC;


-- -------------------------------------------------------------
-- 2. Salario medio por departamento e cargo (cargo atual de cada
--    funcionario, identificado pelo registro com data_fim IS NULL
--    em historico_cargos)
-- -------------------------------------------------------------
SELECT 
    d.nome AS departamento,
    c.titulo AS cargo,
    COUNT(f.id) AS qtd_funcionarios,
    ROUND(AVG(hc.salario), 2) AS salario_medio
FROM funcionarios f
JOIN cargos c ON f.cargo_id = c.id
JOIN departamentos d ON c.departamento_id = d.id
JOIN historico_cargos hc ON hc.funcionario_id = f.id AND hc.cargo_id = f.cargo_id AND hc.data_fim IS NULL
WHERE f.status = 'ativo'
GROUP BY d.nome, c.titulo
ORDER BY d.nome, salario_medio DESC;


-- -------------------------------------------------------------
-- 3. Tempo medio (em meses) ate a primeira promocao, por
--    departamento. Usa CTE para isolar a primeira promocao de
--    cada funcionario antes de calcular a media.
-- -------------------------------------------------------------
WITH primeira_promocao AS (
    SELECT 
        hc.funcionario_id,
        MIN(hc.data_inicio) AS data_promocao
    FROM historico_cargos hc
    WHERE hc.motivo = 'promocao'
    GROUP BY hc.funcionario_id
)
SELECT 
    d.nome AS departamento,
    ROUND(AVG(DATEDIFF(pp.data_promocao, f.data_contratacao)) / 30, 1) AS meses_media_ate_promocao,
    COUNT(*) AS qtd_funcionarios_promovidos
FROM primeira_promocao pp
JOIN funcionarios f ON f.id = pp.funcionario_id
JOIN cargos c ON f.cargo_id = c.id
JOIN departamentos d ON c.departamento_id = d.id
GROUP BY d.nome
ORDER BY meses_media_ate_promocao;


-- -------------------------------------------------------------
-- 4. Top 10 maiores crescimentos salariais em uma promocao.
--    Usa a window function LAG() para comparar o salario atual
--    com o salario da etapa anterior da carreira do funcionario.
-- -------------------------------------------------------------
WITH carreira_com_anterior AS (
    SELECT 
        hc.funcionario_id,
        hc.salario,
        hc.data_inicio,
        hc.motivo,
        LAG(hc.salario) OVER (PARTITION BY hc.funcionario_id ORDER BY hc.data_inicio) AS salario_anterior
    FROM historico_cargos hc
)
SELECT 
    f.nome,
    d.nome AS departamento,
    cca.salario_anterior,
    cca.salario AS salario_novo,
    ROUND(((cca.salario - cca.salario_anterior) / cca.salario_anterior) * 100, 1) AS crescimento_percentual
FROM carreira_com_anterior cca
JOIN funcionarios f ON f.id = cca.funcionario_id
JOIN cargos c ON f.cargo_id = c.id
JOIN departamentos d ON c.departamento_id = d.id
WHERE cca.motivo = 'promocao'
ORDER BY crescimento_percentual DESC
LIMIT 10;


-- -------------------------------------------------------------
-- 5. Taxa de turnover (desligamento) por departamento.
--    Usa CASE WHEN dentro de SUM() como contador condicional.
-- -------------------------------------------------------------
SELECT 
    d.nome AS departamento,
    COUNT(DISTINCT f.id) AS total_ja_passou,
    SUM(CASE WHEN f.status = 'inativo' THEN 1 ELSE 0 END) AS desligados,
    ROUND(SUM(CASE WHEN f.status = 'inativo' THEN 1 ELSE 0 END) / COUNT(DISTINCT f.id) * 100, 1) AS taxa_turnover_pct
FROM funcionarios f
JOIN cargos c ON f.cargo_id = c.id
JOIN departamentos d ON c.departamento_id = d.id
GROUP BY d.nome
ORDER BY taxa_turnover_pct DESC;


-- -------------------------------------------------------------
-- 6. Estrutura de lideranca: quantos subordinados diretos cada
--    lider tem. Usa self-join (a tabela funcionarios "unida"
--    com ela mesma, atraves do relacionamento gerente_id).
-- -------------------------------------------------------------
SELECT 
    gerente.nome AS lider,
    c.titulo AS cargo_do_lider,
    COUNT(subordinado.id) AS qtd_subordinados_diretos
FROM funcionarios gerente
JOIN funcionarios subordinado ON subordinado.gerente_id = gerente.id
JOIN cargos c ON gerente.cargo_id = c.id
WHERE gerente.status = 'ativo'
GROUP BY gerente.nome, c.titulo
ORDER BY qtd_subordinados_diretos DESC;
