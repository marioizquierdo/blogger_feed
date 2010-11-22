# BloggerFeed
# == Schema Information
# Schema version: 20100830082032
#
# Table name: blogger_feeds
#
#  id                  :integer(4)      not null, primary key
#  blog_name           :string(255)
#  blog_id             :string(255)
#  feed_id             :string(255)
#  link_self_href      :string(255)
#  link_alternate_href :string(255)
#  title               :string(255)
#  etag                :string(255)
#

class BloggerFeed < ActiveRecord::Base
  
  has_many :entries, :class_name => 'BloggerFeedEntry', 
      :order => 'published DESC',
      :dependent => :delete_all, 
      :autosave => true
  
  validates_presence_of :blog_name, :blog_id
  validates_uniqueness_of :blog_name, :blog_id
  
  # Con esto, se pueden obtener los blogs de BBDD a través de su definición en global_constants.rb
  # Ejemplo: BloggerFeed[:teixo]
  def self.[](blog_name)
    BloggerFeed.find_by_blog_name(blog_name.to_s)
  end
  
  # Equivalencia entre un RSS::Atom::Feed
  # y los atributos de este modelo
  def self.attributes_from_xml_atom_feed(feed)
    attrs = {
      :feed_id  => feed.elements['id'].text, # /feed/id
      :title    => feed.elements['title'].text # /feed/title
    }
    feed.elements.each('link') do |link|
      attrs[:link_self_href]      = link.attribute('href').value if link.attribute('rel') and link.attribute('rel').value == 'self' # /feed/link[[@rel="self"]]/@href
      attrs[:link_alternate_href] = link.attribute('href').value if link.attribute('rel') and link.attribute('rel').value == 'alternate' and link.attribute('type').value == 'text/html' # /feed/link[[]@rel="alternate"][[]@type="text/html"]/@href
      attrs[:link_atom_xml_href]  = link.attribute('href').value if link.attribute('type') and link.attribute('type').value == 'application/atom+xml' # /feed/link[@rel="http://schemas.google.com/g/2005#feed"][@type="application/atom+xml"]/@href
    end
    attrs.delete :link_atom_xml_href unless BloggerFeed.new.attribute_names.include? 'link_atom_xml_href' # adaptador porque en la primera version no existia este attributo, asi los create que hay en las migrations antiguas no fallaran
    attrs
  end
  
  # Carga el blogger_feed de BBDD a partir del blog_id y actualiza sus datos.
  # (ver el método del objeto update_from_source)
  # Nota: si no hay ningún blogger_feed en BBDD con ese blog_name lanza una exception.
  # Ejemplo: BloggerFeed.update_from_source :teixo
  def self.update_from_source(blog_name)
    blogger_feed = BloggerFeed[blog_name]
    raise "BloggerFeed with blog_name = #{blog_name.inspect} not found."
    blogger_feed.update_from_source
  end
  
  # Actualizar los datos de la BBDD con los del blog mediante su RSS.
  # Puede lanzar una exception si hay algún problema con la conexión HTTP o hay algún error al guardar los cambios en BBDD.
  # ===== Options
  #  * :force_reload => false por defecto. Si se pone a true, elimina todas la entries actuales del feed para luego crearlas de nuevo.
  #                      La optimización con el etag se mantiene, es decir, que si no hay cambios en la url remota, no hace nada.
  #  * :load_max_results => 1000 por defecto. Es el número de entradas que se piden como máximo al feed RSS.
  # ===== Returns 
  # Un hash con información sobre la operación:
  #  * :created => integer, número de entradas recibidas para añadir
  #  * :updated => integer, número de entradas recibidas para actualizar
  #  * :deleted => integer, número de entradas eliminadas (Sin implementar por ahora. Para eliminar entradas hay que hacer un reload total)
  #  * :http_status => string, código y descripción de status http devuelto. Suele ser "202, OK", o "304, Not Modified".
  #  * :source_url => string, url de donde se leen los feeds.
  #
  # ===== Implementación:
  # Primero detecta si los datos en el blog han cambiado (usando la cabecera HTTP eTag, ver http://code.google.com/apis/blogger/docs/2.0/developers_guide_protocol.html#RetrievingCached)
  # y si es así, parsea el resultado (XML ATOM Feed), actualiza los datos del objeto y lo vuelve a guardar.
  # Por defecto pide solamente las entries que han sido modificadas desde la última fecha (guardada en el atributo updated_from_source_timestamp),
  # y luego va añadiendo o modificando aquellas que sea necesario. 
  # Por ahora no hay ningún mecanismo para eliminar entradas de forma optimizada, para ello hay que poner el parámetro force_reload = true 
  # (así se borran todas y luego se crean de nuevo, de forma que los eliminados ya no llegan).
  def update_from_source(options = {})
    
    # Options default values
    options[:force_reload] = false unless options.include? :force_reload
    options[:load_max_results] ||= 2000
    
    # Return data
    ret_data = {:created => 0, :updated => 0, :deleted => 0}
    
    # HTTP Headers
    http_headers = {} # NO se usan headers especiales ahora (el cliente de Blogger ya usa los necesaios y el etag no hace falta si se usa la optimizacion de las fechas con updated-min)
    http_headers["If-None-Match"] = self.etag || 'XXX' unless options[:force_reload] # con esto devuelve un error 304 si el etag del feed del servidor es el mismo, es decir, si no ha cambiado. Ver: http://code.google.com/apis/blogger/docs/2.0/developers_guide_protocol.html#RetrievingCached
    
    # Blogger Data API client: http://gdata-ruby-util.googlecode.com/svn/trunk/doc/classes/GData/Client/Blogger.html
    # Google Data for Ruby: http://code.google.com/intl/es-ES/apis/gdata/articles/gdata_on_rails.html
    require 'gdata'
    client = GData::Client::Blogger.new :headers => http_headers
    
    # Login using ClientLogin, if it's a private blog
    client.clientlogin(client_login_email, client_login_password) if client_login_email.present? and client_login_password.present?

    # Url with parameters
    url = url_from_blog_id
    params = [] # parámetros que se le pueden pasar a Google Data API: http://code.google.com/intl/es-ES/apis/blogger/docs/2.0/developers_guide_protocol.html#RetrievingWithQuery
    params << "max-results=#{options[:load_max_results]}" # el valor por defecto de blogger es 25, que es demasiado pequeño para este caso. Nosotros ponemos 1000 por defecto.
    if self.updated_from_source_timestamp.present? and not options[:force_reload] # cargar solo las entries que hayan sido modificadas.
      params << "orderby=updated" if self.updated_from_source_timestamp.present? # updated-min and updated-max parameters are ignored unless the orderby parameter is set to updated
      params << "updated-min=#{updated_from_source_timestamp.utc.iso8601}" # si no es RFC 3339 (que es el necesario) desde luego se le parece mucho
    end
    url += '?'+params.join('&') unless params.empty?
    ret_data[:source_url] = url
    
    # Accessing Feeds
    begin
      http_response = client.get(url)
    rescue GData::Client::UnknownError => http_error # Errors can be: http://gdata-ruby-util.googlecode.com/svn/trunk/doc/classes/GData/Client/Base.src/M000014.html
      if http_error.response.status_code.to_s == '304' # esto no se considera un error poque hemos utilizado el http_header 'If-None-Match'
       ret_data[:http_status] = "304, Not Modified"
       return ret_data
      else
        raise http_error # error 3xx, 4xx, or 5xx
      end
    end
    feed = http_response.to_xml
  
    # Copy data into BloggerFeed instance
    self.attributes = self.attributes.merge BloggerFeed.attributes_from_xml_atom_feed(feed)
    self.etag = http_response.headers['etag'] # se obtiene de la cabecera HTTP devuelta. Así se guarda para comprobar en la próxima llamada si han cambiado los datos.
    
    # Update or create new entries
    if options[:force_reload]
      ret_data[:deleted] = self.entries.size
      self.entries.clear
    end
    feed.elements.each('entry') do |entry|
      if not options[:force_reload] and (blogger_feed_entry = self.entries.find_by_entry_id entry.elements['id'].text)
        blogger_feed_entry.update_attributes! BloggerFeedEntry.attributes_from_xml_atom_feed_entry(entry)
        ret_data[:updated] += 1
      else
        self.entries.build BloggerFeedEntry.attributes_from_xml_atom_feed_entry(entry) # se guardan luego por el :autosave => true del has_many
        ret_data[:created] += 1
      end
    end
    
    # Guardar cambios
    self.updated_from_source_timestamp = Time.now.to_datetime # anotar el momento del cambio
    self.save!
    return ret_data
  end
  
  
  # Crear un nuevo BloggerFeed a partir de los datos del blog con blogID de Blogger.
  # Hay que especificar el blog_name y el blog_id, que son obligatorios:
  #  * blog_name:     Identificador local y libre del blog. Cada blog_name está asociado a un único blog_id y viceversa (digamos que blog_name sería blog_id.humanize)
  #  * blog_id:       Identificador del blog dentro de blogger. Se puede saber cual es el blog_id de un blog a través
  #                   del parámetro blogID de los links de la interfaz de administración en blogger, que es un número de 19 cifras. Nosotros aquí lo guardamos como String.
  #  * optional_attrs: Son otros atributos que se pueden especificar a la hora de crear el blogger_feed. Se podrán modificar desde la consola con las tareas rake blogger_feed
  #    * :link_to_public_feed_address => Referencia al feed si es externo a blogger, por ejemplo si se utiliza FeedBurner. Se puede añadir más adelante con rake blogger_feed:set_link_to_public_feed_address
  #    * :client_login_email => Si el blog es privado, necesita una direccion de email para conectarse. Se puede añadir más adelante con rake blogger_feed:update_client_login_access
  #    * :client_login_password => Si el blog es privado, necesita una contraseña. Se puede añadir más adelante con rake blogger_feed:update_client_login_access
  # Ejemplo: BloggerFeed.create_from_source 'teixo', '4464995559175070360'
  # Nota: Esto es solo para crear los blogs en la BBDD,
  #       normalmente se invoca desde una migration ya que solamente hay que crearlos una vez.
  def self.create_from_source(blog_name, blog_id, optional_attrs={})
    attrs = optional_attrs.merge :blog_name => blog_name, :blog_id => blog_id.to_s
    feed = BloggerFeed.create!(attrs) # creación básica del feed, solo con los identificadores y los argumentos adicionales añadidos
    feed.update_from_source
  end
  
  # Url que apunta al blog en Blogger
  # Enlace por defecto
  def link
    link_alternate_href
  end
  
  # Url del feed redirigido. Por ejemplo a feedburner.
  # Esta url es para poner en los enlaces que mandan al rss del sitio directamente desde un enlace del navegador.
  # La dirección url_from_blog_id: "http://www.blogger.com/feeds/#{blog_id}/posts/default"
  # no redirige a feedburner aunque esté habilitada la redirección en el blog de blogger.
  def redirected_rss_url
    link_atom_xml_href
  end
  
  # Por optimización, devuelve las entries igual que lo haría blogger_feed.entries,
  # pero selecciona solo aquellos campos necesarios para mostrar los sumarios (evita tener que cargar el content de todos ellos).
  # Ideal para el helper show_teixo_blog_feed_entries() de la vista.
  def entries_summary(options = {})
    options[:limit] ||= 3 # por defecto carga solo las últimas 3 entradas
    options[:select] ||= 'id, title, summary, link_alternate_href, clean_url_id, published'
    self.entries.all options
  end
    
  
  # Equivalencia entre blogID y la url en blogger donde obtener el RSS
  def url_from_blog_id
    "http://www.blogger.com/feeds/#{blog_id}/posts/default"
  end
  
end