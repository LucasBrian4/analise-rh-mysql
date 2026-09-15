import os
import random
from datetime import date, timedelta
 
import mysql.connector
from dotenv import load_dotenv
from faker import Faker
 
load_dotenv()
 
fake = Faker("pt_BR")
random.seed(42)
 
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": os.getenv("DB_PASSWORD"),
    "database": "rh_empresa",
}
 
DEPARTAMENTOS = [
    "Tecnologia da Informacao",
    "Recursos Humanos",
    "Financeiro",
    "Marketing",
    "Vendas",
]
 
NIVEIS = {
    "Jr": (2800, 4000),
    "Pleno": (4200, 6500),
    "Senior": (6800, 10000),
    "Gerente": (11000, 16000),
}
 
PREFIXO_CARGO = {
    "Tecnologia da Informacao": "Analista de TI",
    "Recursos Humanos": "Analista de RH",
    "Financeiro": "Analista Financeiro",
    "Marketing": "Analista de Marketing",
    "Vendas": "Analista de Vendas",
}
 
QTD_POR_NIVEL = {"Gerente": 1, "Senior": 2, "Pleno": 4, "Jr": 5}
 
 
def conectar():
    return mysql.connector.connect(**DB_CONFIG)
 
 
def inserir_departamentos(cursor):
    ids = {}
    for nome in DEPARTAMENTOS:
        data_criacao = fake.date_between(start_date="-15y", end_date="-5y")
        cursor.execute(
            "INSERT INTO departamentos (nome, data_criacao) VALUES (%s, %s)",
            (nome, data_criacao),
        )
        ids[nome] = cursor.lastrowid
    return ids
 
 
def inserir_cargos(cursor, dept_ids):
    ids = {}
    for dept_nome, dept_id in dept_ids.items():
        prefixo = PREFIXO_CARGO[dept_nome]
        for nivel, (sal_min, sal_max) in NIVEIS.items():
            titulo = f"{prefixo} {nivel}" if nivel != "Gerente" else f"Gerente de {dept_nome}"
            cursor.execute(
                """INSERT INTO cargos (titulo, departamento_id, salario_min, salario_max)
                   VALUES (%s, %s, %s, %s)""",
                (titulo, dept_id, sal_min, sal_max),
            )
            ids[(dept_nome, nivel)] = cursor.lastrowid
    return ids
 
 
def gerar_data_contratacao(nivel):
    anos_max = {"Gerente": 12, "Senior": 8, "Pleno": 5, "Jr": 3}[nivel]
    return fake.date_between(start_date=f"-{anos_max}y", end_date="-30d")
 
 
def inserir_funcionarios_e_historico(cursor, dept_ids, cargo_ids):
    ordem_promocao = ["Jr", "Pleno", "Senior", "Gerente"]
 
    for dept_nome in DEPARTAMENTOS:
        gerente_id_atual = None
        seniors_e_plenos = []
 
        for nivel in ["Gerente", "Senior", "Pleno", "Jr"]:
            qtd = QTD_POR_NIVEL[nivel]
            for _ in range(qtd):
                nome = fake.name()
                email = fake.unique.email()
                nascimento = fake.date_of_birth(minimum_age=22, maximum_age=60)
                contratacao = gerar_data_contratacao(nivel)
 
                if nivel == "Gerente":
                    gerente_id = None
                elif nivel in ("Senior", "Pleno"):
                    gerente_id = gerente_id_atual
                else:
                    gerente_id = random.choice(seniors_e_plenos) if seniors_e_plenos else gerente_id_atual
                inativo = random.random() < 0.05
                status = "inativo" if inativo else "ativo"
 
                cargo_atual_id = cargo_ids[(dept_nome, nivel)]
 
                cursor.execute(
                    """INSERT INTO funcionarios
                       (nome, email, data_nascimento, data_contratacao, cargo_id, gerente_id, status)
                       VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                    (nome, email, nascimento, contratacao, cargo_atual_id, gerente_id, status),
                )
                func_id = cursor.lastrowid
 
                if nivel == "Gerente":
                    gerente_id_atual = func_id
                if nivel in ("Senior", "Pleno"):
                    seniors_e_plenos.append(func_id)
 
                niveis_percorridos = ordem_promocao[: ordem_promocao.index(nivel) + 1]
                data_inicio_etapa = contratacao
                dias_totais = (date.today() - contratacao).days
                dias_por_etapa = max(dias_totais // len(niveis_percorridos), 180)
 
                for i, nivel_etapa in enumerate(niveis_percorridos):
                    cargo_etapa_id = cargo_ids[(dept_nome, nivel_etapa)]
                    ultima_etapa = i == len(niveis_percorridos) - 1
 
                    if ultima_etapa:
                        data_fim_etapa = None if not inativo else data_inicio_etapa + timedelta(
                            days=random.randint(60, 400)
                        )
                        motivo = "contratacao" if i == 0 else "promocao"
                    else:
                        data_fim_etapa = data_inicio_etapa + timedelta(days=dias_por_etapa)
                        motivo = "contratacao" if i == 0 else "promocao"
 
                    sal_min, sal_max = NIVEIS[nivel_etapa]
                    salario = round(random.uniform(sal_min, sal_max), 2)
 
                    cursor.execute(
                        """INSERT INTO historico_cargos
                           (funcionario_id, cargo_id, salario, data_inicio, data_fim, motivo)
                           VALUES (%s, %s, %s, %s, %s, %s)""",
                        (func_id, cargo_etapa_id, salario, data_inicio_etapa, data_fim_etapa, motivo),
                    )
 
                    data_inicio_etapa = data_fim_etapa
 
                if inativo:
                    data_desligamento = data_inicio_etapa or contratacao
                    cursor.execute(
                        """INSERT INTO historico_cargos
                           (funcionario_id, cargo_id, salario, data_inicio, data_fim, motivo)
                           VALUES (%s, %s, %s, %s, %s, %s)""",
                        (func_id, cargo_atual_id, salario, data_desligamento, data_desligamento, "desligamento"),
                    )
 
 
def main():
    conexao = conectar()
    cursor = conexao.cursor()
 
    print("Inserindo departamentos...")
    dept_ids = inserir_departamentos(cursor)
 
    print("Inserindo cargos...")
    cargo_ids = inserir_cargos(cursor, dept_ids)
 
    print("Inserindo funcionarios e historico de carreira...")
    inserir_funcionarios_e_historico(cursor, dept_ids, cargo_ids)
 
    conexao.commit()
    cursor.close()
    conexao.close()
    print("Concluido! Banco populado com sucesso.")
 
 
if __name__ == "__main__":
    main()
 