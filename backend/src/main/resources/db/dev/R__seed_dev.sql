INSERT INTO barbeiros (nome, email, senha, slug)
VALUES ('Barbeiro Dev', 'dev@barbearia.local', '$2a$10$a6gZ0alrX.yyL5p7jIrVo.cWaJX/I2esp.GBFexRVkZPthR5romQG', 'barbeiro-dev')
ON CONFLICT (email) DO NOTHING;
