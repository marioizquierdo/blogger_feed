BloggerFeed
===========

BloggerFeed es un modelo que representa un feed de algún blog de Blogger.
Lee automáticamente el feed a través del RSS del blog, y después se puede actualizar con la tarea rake blogger_feed:refresh_all


Instalación
-----------

Necesita la gema gdata: http://code.google.com/intl/es-ES/apis/gdata/articles/gdata_on_rails.html
Añadir en environment.rb:
  config.gem 'gdata', :lib => 'gdata'


Crear una nueva migration con el contenido de las migrations que hay en blogger_feed/lib/db/migrate
para añadir las nuevas tablas y crear los nuevos feeds.


USO
---

Crear un nuevo feed (desde una migration, por ejemplo):
  BloggerFeed.create_from_source 'example_blog', '1230444769005184054' # http://www.blogger.com/feeds/1230444769005184054/posts/default

Añadir o modificar noticias desde la interfaz de administración de Blogger.
Luego para actualizar el feed:
  $rake blogger_feed:refresh blog_id=example_blog

Si hay varios blogs, se puede utilizar
  $rake blogger_feed:refresh_all

Para acceder a las entradas desde un controlador:
  @blogger_feed_entries = BloggerFeed['example_blog'].entries.all

O utilizando el plugin will_paginate
  @blogger_feed_entries = BloggerFeed['example_blog'].entries.paginate :page => params[:page]

Si el blog es privado, hay que añadir el email y la contraseña con la que se quiere acceder mediante:
  $rake blogger_feed:update_client_login_access blog_name=example_blog email=account@gmail.com password=MyPassWd
  
Y si más adelante se hace público de nuevo, se puede eliminar el email y la contraseña con:
  $rake blogger_feed:update_client_login_access blog_name=example_blog public_access=true
  
Para utilizar una dirección externa donde apuntar los enlaces de suscripción al feed, se puede utilizar
  @blogger_feed.link_atom_xml_href
  
..siempre que nos valga la dirección que nos da blogger. Si queremos tener otra dirección (por ejemplo a FeerBurner), hay que añadirla manualmente
  $rake blogger_feed:set_link_to_public_feed_address BLOG_NAME=teimas_es VALUE=http://feeds.feedburner.com/teimas_es
y después desde las vistas se puede utilizar este link:
  @blogger_feed.link_to_public_feed_address


__NOTA__: La representación de las entradas en la vista no forma parte del plugin. Hay que crear las vistas para los BloggerFeedEntry.



Copyright (c) 2010 Mario Izquierdo, released under the MIT license
