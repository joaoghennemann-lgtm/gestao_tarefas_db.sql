CREATE TABLE colaboradores (
    id_colaborador SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha TEXT NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_cadastro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email_colaborador CHECK (POSITION('@' IN email) > 1)
);


CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    descricao VARCHAR(200) NOT NULL
);

CREATE TABLE tarefas (
    id_tarefa SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descricao TEXT,
    id_categoria INTEGER NOT NULL,
    id_colaborador INTEGER NOT NULL,
    data_agendamento TIMESTAMP NOT NULL,
    prazo_entrega DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pendente',
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tarefa_categoria
        FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_tarefa_colaborador
        FOREIGN KEY (id_colaborador) REFERENCES colaboradores(id_colaborador),
    CONSTRAINT chk_status_tarefa
        CHECK (status IN ('Pendente', 'Em andamento', 'Concluida', 'Cancelada')),
    CONSTRAINT chk_prazo_tarefa
        CHECK (prazo_entrega >= DATE(data_agendamento))
);

CREATE TABLE historico_tarefas (
    id_historico SERIAL PRIMARY KEY,
    id_tarefa INTEGER NOT NULL,
    acao VARCHAR(100) NOT NULL,
    detalhes TEXT NOT NULL,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historico_tarefa
        FOREIGN KEY (id_tarefa) REFERENCES tarefas(id_tarefa)
);


CREATE OR REPLACE FUNCTION fn_validar_tarefa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ativo BOOLEAN;
BEGIN
    SELECT ativo
      INTO v_ativo
      FROM colaboradores
     WHERE id_colaborador = NEW.id_colaborador;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Colaborador % nao existe.', NEW.id_colaborador;
    END IF;

    IF v_ativo = FALSE THEN
        RAISE EXCEPTION 'Nao e permitido atribuir tarefa a colaborador inativo.';
    END IF;

    IF NEW.data_criacao IS NULL THEN
        NEW.data_criacao := CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_tarefa
BEFORE INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tarefa();


CREATE OR REPLACE FUNCTION fn_registrar_historico_tarefa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO historico_tarefas (id_tarefa, acao, detalhes)
    VALUES (
        NEW.id_tarefa,
        'Criacao da tarefa',
        'Tarefa "' || NEW.titulo || '" cadastrada no sistema.'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_historico_tarefa
AFTER INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historico_tarefa();


INSERT INTO colaboradores (nome, email, senha, ativo) VALUES
('Ana Souza', 'ana.souza@empresa.com', 'senha123', TRUE),
('Bruno Lima', 'bruno.lima@empresa.com', 'bruno456', TRUE),
('Carla Mendes', 'carla.mendes@empresa.com', 'carla789', TRUE);

INSERT INTO categorias (nome, descricao) VALUES
('Administrativo', 'Tarefas administrativas e organizacionais'),
('Tecnologia', 'Tarefas relacionadas a sistemas e tecnologia'),
('Planejamento', 'Tarefas de planejamento e acompanhamento');

INSERT INTO tarefas
(titulo, descricao, id_categoria, id_colaborador, data_agendamento, prazo_entrega, status)
VALUES
('Organizar documentos', 'Revisar e organizar documentos do projeto.', 1, 1,
 CURRENT_TIMESTAMP + INTERVAL '1 day', CURRENT_DATE + 3, 'Pendente'),
('Atualizar sistema', 'Verificar e atualizar os dados do sistema.', 2, 2,
 CURRENT_TIMESTAMP + INTERVAL '2 days', CURRENT_DATE + 5, 'Em andamento'),
('Planejar reuniao', 'Preparar pauta e cronograma da reuniao.', 3, 3,
 CURRENT_TIMESTAMP + INTERVAL '3 days', CURRENT_DATE + 8, 'Pendente');



CREATE OR REPLACE FUNCTION fn_buscar_colaboradores(p_termo TEXT)
RETURNS TABLE (
    id_colaborador INTEGER,
    nome VARCHAR(100),
    email VARCHAR(150),
    ativo BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id_colaborador, c.nome, c.email, c.ativo
      FROM colaboradores AS c
     WHERE c.nome ILIKE '%' || p_termo || '%'
        OR c.email ILIKE '%' || p_termo || '%'
     ORDER BY c.nome;
END;
$$;


CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT
    c.nome AS nome_colaborador,
    t.titulo AS titulo_tarefa,
    cat.nome AS categoria,
    t.prazo_entrega,
    t.status
FROM tarefas AS t
INNER JOIN colaboradores AS c
        ON t.id_colaborador = c.id_colaborador
INNER JOIN categorias AS cat
        ON t.id_categoria = cat.id_categoria;


CREATE OR REPLACE VIEW vw_cronograma_prazos AS
SELECT
    t.id_tarefa,
    t.titulo AS titulo_tarefa,
    t.data_agendamento,
    t.prazo_entrega,
    t.status,
    (t.prazo_entrega - CURRENT_DATE) AS dias_restantes,
    c.nome AS responsavel
FROM tarefas AS t
INNER JOIN colaboradores AS c
        ON t.id_colaborador = c.id_colaborador
ORDER BY t.prazo_entrega ASC, t.data_agendamento ASC;


SELECT * FROM vw_painel_principal;

SELECT * FROM vw_cronograma_prazos;

SELECT * FROM fn_buscar_colaboradores('Ana');


SELECT * FROM historico_tarefas ORDER BY data_registro;


SELECT 'colaboradores' AS tabela, COUNT(*) AS quantidade FROM colaboradores
UNION ALL
SELECT 'categorias', COUNT(*) FROM categorias
UNION ALL
SELECT 'tarefas', COUNT(*) FROM tarefas
UNION ALL
SELECT 'historico_tarefas', COUNT(*) FROM historico_tarefas;