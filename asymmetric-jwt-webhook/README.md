**Please use one of the following languages (unless agreed otherwise with your interviewer): _Kotlin/Java/Scala_, _Python_, _Go_, _PL/pgSQL_, _Elixir_, _C/C++/C#_, _Rust_**

# Asymmetric JWT webhook authentication

## Requirements

Implement a simple webhook service/endpoint that listens for POST requests coming from an external vendor. The webhook will contain a JSON payload in the request body and a header, `x-{vendor_id}-token` (e.g.: `x-acme-token`), containing an asymmetrically signed JWT token. The JWT token will contain, among others, a `nonce` that should be returned in the response (see `nonce` field in the JSON response example below).

The request body will contain an `email` field. If the provided token is valid and the email exists in the database, the service should then retrieve the corresponding user profile and return it as a JSON.

For a request similar to the following:

```
curl --location --request POST 'http://localhost:8080/api/v1/webhook' \
--header 'x-acme-token: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzM4NCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibm9uY2UiOiIwYTUzOTg5Zi0zZDk3LTQ2NDItOTE1My0wM2ZhYjFhM2UwODEiLCJleHAiOjE2MzM0NzQ3MTF9.qX6wdeC4tAaDrirn7VFBkxf52UAI0GeIvAx_uV_7FrHNze4O1uupTr5KMmO7WoqeFi8y_8Yk5SiPhMG6WNeKJLJfEtYMT-eBPLla9BjtjZUVOT_Vw82wEnmQuFUyKGm2'
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "franz.kafka@gmail.com"
}'
```

the implemented service should return an HTTP `200` response with the following JSON format, in case a user with that email exists in our database:

```json
{
  "nonce": "SAME VALUE FOUND IN THE REQUEST TOKEN",
  "user_id": "...",
  "first_name": "...",
  "last_name": "...",
  "email": "...",
  "dob": "...",
  "phone": "...",
  "addresses": [
    {
      "id": "...",
      "line1": "...",
      "line2": "...",
      "city": "...",
      "state": "...",
      "county": "...",
      "zip": "...",
      "country": "..."
    }
  ]
}
```

In case no user is found, simply return a `204` response.

## Verifying the webhook signature

Requests will always be signed with an asymmetric JSON Web Token signed with a private key. Your service needs to verify the token with the public key stored in the database for the requesting vendor.

1. Choose a JWT library that supports `ES384`. That's the algorithm used to sign the token.
2. Read the HTTP request header `x-{vendor_id}-token`.
3. Fetch the vendor's public key from the table `vendors.public_key`.
4. Using the `verify` function with the algorithm ES384, verify the provided `x-{vendor_id}-token` against the public key.

## Tips and hints

- If you would like to use `psql` to explore the database and make direct queries, etc, use `johndoe`. (see more details in the `docker-compose.yml` file)
- For the application access itself, make considerations about what type of user would be more appropriate and the safest to use (think "_least privilege principle_" here). Take a look at `init/roles.sql`. You can either choose an existing role that you think would be appropriate, or create a new one.
- If you need to change a role's password, you can use a command like `ALTER USER some_user PASSWORD 'my_n3w_p4ssw0rd';`
- Please do not modify any of the existing files within `init`. You can add new ones and make the required adjustments in the `docker-compose.yml` file.
- Please do not forget submit/commit any insertions/updates you made to the database, if any.
- Use some of the links below to generate public/private key pairs and JWTs for testing.
- Don't hesitate to ask us questions if something is not clear.
- Have fun! ;)

## Useful links and references

- https://jwt.io
- https://token.dev
- https://www.postgresql.org/docs/9.6/index.html
- https://start.ktor.io
- https://start.spring.io
- https://ktor.io/docs/jwt.html#realm
- https://docs.docker.com/compose/reference/start/
- https://docs.docker.com/compose/gettingstarted/
