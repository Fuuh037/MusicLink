# Configurar o SMTP do Gmail no Supabase

O Music Link usa confirmação por e-mail. O SMTP personalizado precisa ser configurado no painel Supabase para aceitar cadastros de qualquer endereço.

## 1. Criar uma senha de app no Google

1. Entre na conta Gmail que será usada para enviar mensagens do Music Link.
2. Ative a verificação em duas etapas na Conta Google.
3. Abra Segurança → Senhas de app e crie uma senha para o Music Link.
4. Guarde a senha de app em local seguro. Não a envie pelo chat nem a inclua nos arquivos do site.

## 2. Preencher o Supabase

Abra Authentication → Emails → SMTP Settings no projeto MusicLink e ative o SMTP personalizado.

- Host: smtp.gmail.com
- Porta: 587, com STARTTLS
- Usuário: endereço completo da conta Gmail
- Senha: senha de app criada na Conta Google
- Nome do remetente: Music Link
- Endereço do remetente: o mesmo endereço Gmail

Salve a configuração e faça um teste de cadastro com uma caixa de e-mail que você controla. Confirme a chegada da mensagem e o retorno ao domínio https://escolarprojectmusiclink.netlify.app/.

O Gmail precisa da verificação em duas etapas para emitir senhas de app. Contas de escola/trabalho ou com Proteção Avançada podem não oferecer esse recurso. Nesse caso, use um provedor SMTP dedicado.

## Referências

- Mailtrap: https://mailtrap.io/pt/blog/gmail-smtp/
- Supabase: https://supabase.com/docs/guides/auth/auth-smtp
- Google: https://support.google.com/accounts/answer/185833
