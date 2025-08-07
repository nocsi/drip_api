```
mix ash.gen.resource Kyozo.Workspaces.Workspace \
--default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --attribute name:string:required:public \
  --relationship belongs_to:team:Kyozo.Workspaces.Team \
  --relationship belongs_to:user:Kyozo.Accounts.User \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

mix ash.gen.resource Kyozo.Files.File \
  --default-actions read \
  --uuid-primary-key id \
  --attribute subject:string:required:public \
  --relationship belongs_to:representative:Helpdesk.Support.Representative \
  --timestamps \
  --extend postgres,graphql

```

```
mix ash.gen.resource Kyozo.Teams.Team \
  --default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key string \
  --attribute name:string:required:public \
  --attribute shorthand:string:required:public \
  --attribute description:string:public \
  --attribute member_count:integer:public \
  --attribute workspace_count:integer:public \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

```

```
mix ash.gen.domain Kyozo.Files

mix ash.gen.resource Kyozo.Workspaces.File \
--default-actions read,create,update,destroy \
  --uuid-primary-key id \
  --uuid-v7-primary-key \
  --attribute slug:string:required:public \
  --attribute filename:string:required:public \
  --attribute content_type:string:required:public \
  --attribute hash:string:required:public \
  --attribute size:string:required:public \
  --attribute path:string:required:public \
  --attribute combined_hashes:map:required:public \
  --attribute version:string:required:public \
  --attribute status:Ecto.Enum:["pending", "processing", "completed", "failed"]:required:public \
  --relationship belongs_to:user:Kyozo.Accounts.User \
  --relationship belongs_to:workspace:Kyozo.Workspaces.Workspace \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource

mix ash.gen.resource Kyozo.Workspaces.File.Media \



mix ash_phoenix.gen.live --domain  Kyozo.Files --resource Kyozo.Files.File --resourceplural artists
```

```
mix ash.gen.domain Store.Seller

mix ash.gen.resource Store.Seller.Seller \
  --default-actions read \
  --uuid-primary-key id \
  --attribute slug:string:required:public \
  --attribute first_name:string:required:public \
  --attribute last_name:string:required:public \
  --attribute street1:string:required:public \
  --attribute street2:string:public \
  --attribute city:string:required:public \
  --attribute state:string:required:public \
  --attribute zip:string:required:public \
  --attribute country:string:required:public \
  --attribute notes:string:public \
  --attribute x:string:public \
  --attribute facebook:string:public \
  --attribute instagram:string:public \
  --attribute domain:string:public \
  --attribute email:string:required:public \
  --attribute phone:string:public \
  --attribute status:string:required:public \
  --attribute role:string:required:public \
  --attribute stripe_id:string:required:public \
  --relationship has_many:product:Store.Product.Product \
  --timestamps \
  --extend postgres,graphql,json_api

mix ash.gen.resource Store.Product.Product \
  --default-actions read \
  --uuid-primary-key id \
  --attribute sku:string:required:public \
  --attribute name:string:required:public \
  --attribute slug:string:required:public \
  --attribute subtitle:string:public \
  --attribute description:string:required:public \
  --attribute featured_image:string:required:public \
  --attribute images:map:public \
  --attribute featured:boolean:required:public \
  --attribute order:integer:public \
  --attribute stripe_id:string:required:public \
  --attribute price:decimal:required:public \
  --relationship belongs_to:seller:Store.Seller.Seller \
  --timestamps \
  --extend postgres,graphql,json_api,AshAdmin.Resource
```
