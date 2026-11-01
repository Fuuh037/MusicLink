# Music Link — ativação do backend

## O que este MVP usa

- Um único login do Supabase Auth para ouvintes, artistas e administradores.
- ml_profiles, ml_artists, ml_artist_posts, ml_artist_views e ml_contact_messages.
- Supabase Storage: artist-previews para áudio de até 15 MB e artist-media para fotos, capas e publicações de até 5 MB.
- RLS: público consulta apenas artistas publicados; artistas editam seus próprios perfis e publicações; admins moderam perfis e mensagens.

As tabelas antigas (`profiles`, `artists`) ficam preservadas e não são apagadas. Durante a ativação, o esquema copia para `ml_profiles` os perfis antigos que já estejam ligados a uma conta do Supabase Auth; isso preserva o acesso da conta administrativa existente. Os perfis de artistas antigos não são migrados automaticamente, pois é necessário confirmar a correspondência de proprietários antes de transferir esses dados. Faça um backup antes de qualquer limpeza. `supabase-update.sql` é legado e não deve ser executado para ativar este MVP.

## Ativar

1. Abra o projeto Supabase da equipe e faça backup/export dos dados existentes.
2. Para um projeto novo, execute todo o supabase-schema.sql, que inclui esquema base e migração de perfis, posts, visitas e imagens. No projeto MusicLink atual, essa migração aditiva já foi aplicada.
3. Em Authentication → URL Configuration, use `https://escolarprojectmusiclink.netlify.app/` como Site URL e mantenha essa mesma URL na lista Redirect URLs. Ela é usada para confirmação de e-mail e recuperação de senha. Em produção, não deixe `localhost` como URL padrão.
4. Confira `supabase-config.js`: use a URL do projeto e a chave `publishable` (ou `anon`) correspondente. Nunca use uma chave `service_role` ou `secret` no navegador.
5. Publique a pasta `MusicLink` em Netlify, Vercel ou outro host estático. `_headers` define cabeçalhos para hosts compatíveis com esse formato; `vercel.json` configura cabeçalhos para Vercel.
6. Crie sua conta pelo site e confirme o e-mail. Para habilitar a primeira conta administradora, copie o UUID do usuário em Authentication → Users e execute no SQL Editor:

```sql
update public.ml_profiles
set role = 'admin'
where user_id = 'UUID-DA-CONTA';
```

7. Entre novamente pelo formulário padrão. O painel de administração aparece conforme o cargo salvo no banco. A conta administrativa existente foi importada; novas contas continuam sendo criadas como artista ou comum e não podem se promover a admin.
8. Para recuperar senha, informe o e-mail na tela de acesso e escolha “Esqueci minha senha”. O link abre o domínio publicado, onde a pessoa define a nova senha.

## Áudio e dados

O site mantém perfis e uma prévia musical curta; não oferece playlists. O áudio é público para reprodução, limitado pelo bucket a 15 MB e enviado para uma pasta identificada pelo ID do usuário dono do perfil. Ao trocar a prévia, o site tenta remover o arquivo anterior após salvar a nova referência. Contatos gerais são salvos como mensagens privadas, visíveis somente para administradores. O e-mail público de um artista é exibido no perfil quando informado.

O cadastro de artista cria o perfil com cargo `artista`; a criação de conta comum cria `comum`. O cadastro nunca pode criar um administrador. A primeira conta admin deve ser promovida pelo SQL Editor como acima.

## Antes de abrir ao público

- Adicione CAPTCHA/rate limit ao formulário de contato se houver spam.
- Confirme que Site URL e Redirect URLs apontam para `https://escolarprojectmusiclink.netlify.app/`; o fluxo de recuperação também usa esse endereço.
- Teste uma conta ouvinte, uma conta artista, uma conta admin, upload e reprodução de áudio, e envio/leitura de contato.
- Os perfis de artistas antigos ainda precisam ser revisados e associados aos respectivos proprietários; a tabela antiga não foi alterada.



## SMTP do Gmail e versão completa do esquema

Para um projeto novo, supabase-schema.sql agora contém o esquema base e também a migração de perfis, publicações, visitas e imagens. No projeto MusicLink, essa migração aditiva já foi aplicada.

O SMTP personalizado do Gmail ainda precisa ser salvo por você no painel Supabase. Siga SMTP_SETUP.md; mantenha a confirmação de e-mail habilitada. O site já direciona a recuperação de senha à página de acesso no domínio publicado.

