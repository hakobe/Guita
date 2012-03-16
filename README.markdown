# Guita

Guita is a gist clone written in Perl.

## Install

1. Create a database named <code>'guita'</code>.
2. Load <code>./db/schema.sql</code> to the database.
3. Write <code>./config.pl</code> like below.
```perl
+{
    github_client_id    => 'YOUR GITHUB APP CLIENT ID',
    github_clientsecret => 'YOUR GITHUB APP CLIENT SECRET',
    session_key_salt    => '123456',

    repository_base     => '/path/to/repos',
    dsn_guita           => 'dbi:mysql:dbname=guita;host=localhost',
}
```
4. <code>carton install</code>
5. <code>carton exex perl script/server.pl</code>

## Authors
- hakobe
