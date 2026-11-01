# Versionamento

O versionamento Git foi retomado por solicitação do usuário em 2026-10-31. Publicações no GitHub e no Netlify devem ocorrer quando solicitadas.

Para cada atualização entregue, criar uma pasta de snapshot e um ZIP datados em outputs/backups/, sem as pastas .git e .netlify. Usar uma versão crescente no nome (por exemplo, MusicLink-v1.1-2026-10-28) e incluir o site e os arquivos de configuração/documentação daquela versão. Manter snapshots anteriores intactos para o usuário copiar ao Drive.

Preservar o repositório Git e os commits existentes. As alterações de código podem continuar sem commits automáticos. Os backups locais são independentes do Git.

O primeiro commit registra o estado após a adaptação para Supabase; não representa uma migração remota concluída. Consulte SUPABASE_SETUP.md para as etapas pendentes.

## MusicLink v1.2 — 2026-10-31

- Diário visual: trava contra envio duplicado enquanto a publicação está em andamento, botão e mensagem de sucesso/erro atualizados, e opção para o artista excluir uma publicação própria.
- O banco Supabase já possui políticas RLS para excluir publicações do próprio artista e apagar os arquivos correspondentes do bucket `artist-media`.
- Snapshot anterior à alteração: `outputs/backups/MusicLink-v1.1-local-before-fix-2026-10-31` e arquivo ZIP homônimo.
- Snapshot desta versão salvo em `outputs/backups/MusicLink-v1.2-2026-10-31` e no arquivo ZIP homônimo.


## MusicLink v1.3 — 2026-10-31

- Removido do site o arquivo legado app.js, que não era carregado por index.html e continha credenciais de demonstração. O site atual utiliza site.js.
- O backup local v1.2 preserva a versão anterior; esta versão tem snapshot próprio em outputs/backups/MusicLink-v1.3-2026-10-31 e ZIP homônimo.

## MusicLink v1.4 — 2026-10-31

- README público resumido para apresentar o site e direcionar visitantes ao Music Link.
- Snapshot local: outputs/backups/MusicLink-v1.4-2026-10-31 e ZIP homônimo.
