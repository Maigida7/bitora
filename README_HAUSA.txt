BITORA STARTER — MUHIMMI

Wannan kunshin na farawa ne kawai, ba cikakken production backend ba.

Fayiloli:
- worker.js: endpoints na health check da D1 connection check kawai.
- wrangler.jsonc: saitin Worker. Dole a maye gurbin database_id da UUID na ainihin bitora-dev daga Cloudflare.
- 0001_initial.sql: tsarin D1 tables (migration draft).

Kada a saka BOT TOKEN, API secret, wallet private key ko seed phrase a GitHub.
Kada a yi amfani da ainihin kuɗin TON ko bayanan masu amfani tukuna.

Lura: GitHub edit screen ɗin da kake ciki yana ƙirƙirar fayil ɗaya kawai. Don haka kada ka manna wannan kunshin gaba ɗaya a worker.js. Za mu saka fayiloli daban-daban, sannan mu saita D1 binding ta hanyar UUID na database.
