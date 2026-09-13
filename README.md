# Caderno — PWA pessoal para professores

Uma base PWA feita em **HTML, CSS e JavaScript puro**, orientada para a agenda anual de 1 de setembro a 31 de agosto. É pensada para uma professora/professor individual: uma conta só pode aceder aos seus próprios dados.

## O que já está pronto

- Ecrã de autenticação e ligação preparada para Supabase Auth.
- Dashboard diário com aulas, alertas, tarefas e notas rápidas.
- Agenda mensal com testes, reuniões e eventos letivos.
- Horário semanal de segunda a sexta-feira.
- Páginas de turmas, alunos, avaliação/grelhas e planeamento anual.
- Layout responsivo, instalável como PWA e cache apenas do *app shell*.
- Grelha de avaliação ligada aos dados da conta.
- Esquema PostgreSQL completo com RLS no Supabase, para que cada conta apenas veja os seus dados.

> Antes de introduzir dados de alunos, aplica o esquema SQL e confirma que as políticas RLS do projeto Supabase estão ativas.

## Abrir localmente

O `service-worker` só funciona através de `http://localhost` ou HTTPS (e não abrindo diretamente o ficheiro).

Com Node.js instalado:

```powershell
npx serve .
```

Abre o endereço indicado, por exemplo `http://localhost:3000`. Cria uma conta ou inicia sessão para abrir a tua agenda.

## Ligar o Supabase

1. Cria um projeto Supabase numa região da União Europeia.
2. Em **Authentication → Providers**, mantém Email ativo e ativa confirmação de email. Configura também MFA/TOTP antes de introduzires dados reais.
3. No **SQL Editor**, executa todo o ficheiro [`supabase/schema.sql`](./supabase/schema.sql).
4. Copia `js/supabase-config.example.js` para `js/supabase-config.js`.
5. Preenche apenas `url` e `anonKey` (a chave pública anónima) no novo ficheiro. Nunca uses uma chave `service_role` no browser.
6. Reinicia o servidor e cria a tua conta pelo ecrã de login.

O ficheiro com a configuração real está ignorado pelo Git. A chave `anon` pode ser exposta numa PWA; a proteção real dos dados é garantida por autenticação e pelas políticas **Row-Level Security** do esquema.

## Dados e funcionalidades

A aplicação lê e grava dados por conta no Supabase: agenda, tarefas, notas, turmas, alunos, horário, avaliações, classificações e planos de aula. Executa o esquema SQL antes de usar a aplicação.

## Segurança e dados de alunos

- Guarda só a informação necessária para o teu trabalho pedagógico.
- Evita colocar diagnósticos, dados de saúde ou informação familiar em campos de observações.
- Mantém o telemóvel com bloqueio de ecrã e não exportes listas/avaliações para dispositivos partilhados.
- Não atives cache offline de fichas de alunos sem PIN local, encriptação e possibilidade de apagar o dispositivo remotamente.
- Configura cópias de segurança, retenção e eliminação para o final de cada ano letivo.

Para tratamento de dados pessoais de alunos, aplica os princípios de minimização, finalidade e proteção adequadas do RGPD. Consulta o texto oficial em [EUR-Lex](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng).
