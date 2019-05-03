
# Clase principal, se instancia con Catalogos.new()
class Catalogos
  require 'ruby-progressbar'
  require 'spreadsheet'
  require 'json'
  require 'net/http'
  require 'fileutils'

  # Codigo para reemplazar caracteres NO ASCII en los encabezados
  # Ref: https://stackoverflow.com/questions/1268289/how-to-get-rid-of-non-ascii-characters-in-ruby
  REPLACEMENTS = { 
    'á' => "a",
    'é' => 'e',
    'í' => 'i',
    'ó' => 'o',
    'ú' => 'u',
    'ñ' => 'n',
    'ü' => 'u'
  }
  

  attr_accessor :local_eTag
  attr_accessor :local_last
  

  # Inicializa la configuracion de encoding y variables de instancia
  def initialize()
    @encoding_options = {
      :invalid   => :replace,     # Replace invalid byte sequences
      :replace => "",             # Use a blank for those replacements
      :universal_newline => true, # Always break lines with \n
      # For any character that isn't defined in ASCII, run this
      # code to find out how to replace it
      :fallback => lambda { |char|
        # If no replacement is specified, use an empty string
        REPLACEMENTS.fetch(char, "")
      },
    }
    @last_eTag = nil
    @local_last = nil
    @catalogos_html_url = "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20_version3-3.htm"
    @catalogos_xls_url = "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/documentos/catCFDI.xls"

  end

  def is_header?(row)

    #verificando headers por color
    if row.formats[0].pattern_fg_color == :silver 
      return true
    end

    #verificando headers por regex de nombre de hoja
    title_regex = /^(c|C)_\w+/
    if title_regex.match(row[0].to_s)

      
      return true
    end

    # verificando headers por existencia de version
    row.each{
      |cell|
      if cell == "Versión"
        
        return true
      end
    }

    return false
      
  end


  # Descarga el .xls de los catalogos del SAT y lo guarda en el folder temporal del sistema operativo.
  # Despues de correr este metodo, se asigna la variable @last_eTag en base al archivo descargado.
  # @param url_excel [String] el url donde el SAT tiene los catalogos, valor default "@catalogos_url"
  # @note Generalmente se mandara llamar vacio a menos que el SAT cambie el url en el futuro.
  def descargar(url_excel = @catalogos_url)

    begin
      puts "Descargando archivo de Excel desde el SAT: #{url_excel}"
      url_excel = URI.parse(url_excel)
      bytesDescargados = 0      
  
      _httpWork = Net::HTTP.start(url_excel.host) do
        |http|
        response = http.request_head(url_excel.path)
        totalSize = response['content-length'].to_i
        @local_last = response['Last-Modified']
        pbar = ProgressBar.create(:title => "Descargando:", :format => "%t %B %p%% %E")
        
        tempdir = Dir.tmpdir()
  
        File.open("#{tempdir}/catalogo.xls", "wb") do |f|
          http.get(url_excel.path) do |str|
            bytesDescargados += str.length 
            relation = 100 * bytesDescargados / totalSize
            pbar.progress = relation
            f.write str          
          end
          pbar.finish()
   
        end
        puts "Descarga de Excel finalizada, guardado en #{tempdir}/catalogo.xls"      
      end
    rescue => e
      puts "Error al momento de descargar: #{e.message}"
      raise
    end

    return true

  end

  def get_url_xls()
    return @catalogos_xls_url
  end

  def get_url_html()
    return @catalogos_html_url
  end
  
  # Genera un folder "catalogosJSON" en la ruta temporal del sistema operativo, requiere que ya exista el .xls generado,
  # usualmente se usa despues de mandar llamar descargar.
  def procesar()

    begin
      Spreadsheet.client_encoding = 'UTF-8'
      
      # Checamos que el archivo de Excel exista previamente
      tempdir = Dir.tmpdir() 
      archivo = "#{tempdir}/catalogo.xls"
  
      
      raise 'El archivo de catálogos de Excel no existe o no ha sido descargado' if File.exist?(archivo) == false
      
      final_dir = "catalogosJSON"
      if File.exist?("#{tempdir}/#{final_dir}")
        FileUtils.rm_rf("#{tempdir}/#{final_dir}")
      end

      Dir.mkdir("#{tempdir}/#{final_dir}")
  
  
      book = Spreadsheet.open(archivo)
      en_partes = false
      ultima_parte = false
      encabezados = Array.new
      renglones_json = nil

      total_hojas = book.worksheets.count

      pbar = ProgressBar.create(:title => "Procesando:", :format => "%t %B %p%%")
      
        
      # Recorremos todas las hojas/catálogos
      for i in 0..book.worksheets.count - 1 
        relation = (i+1) * 100 / total_hojas
        pbar.progress = relation
        hoja = book.worksheet i
      
        #puts "\n\n----------------------------------------------"
        #puts "Conviertiendo a JSON hoja #{hoja.name}..."
      
        # Manejamos la lectura de dos hojas separadas en partes, como la de Codigo Postal  
        if hoja.name.index("_Parte_") != nil
          en_partes = true
          ultima_parte = hoja.name.index("_Parte_2") != nil
          #TODO asume que hay como maximo 2 partes por archivo y que el identificador siempre es "_Parte_X"
        end 

        # Recorremos todos los renglones de la hoja de Excel
        j = 0
        hoja.each do |row|
          j += 1
          # Nos saltamos el primer renglon ya que siempre tiene la descripcion del catálogo, ejem "Catálogo de aduanas ..."  
          if j == 1
            unless is_header?(row)
              next
            end        
          end
  
          break if row.to_s.index("Continúa en") != nil
          next if row.formats[0] == nil 
          # Nos saltamos renglones vacios
          next if row.to_s.index("[nil") != nil

          
          

          if is_header?(row) then
           
            if renglones_json.nil? then
              #puts "Ignorando: #{row}"
              renglones_json = Array.new  
              encabezados = Array.new
            else   
              # Segundo encabezado, el "real"
              # Si ya tenemos encabezados nos salimos
              next if encabezados.count > 0  
              row.each do |col|

                if hoja.name == "c_UsoCFDI"
                  col += " fisica" if col == "Aplica para tipo persona"
                  col = "Aplica para tipo persona moral" if col == nil
                end

                if hoja.name == "c_TipoDeComprobante"
                  col += " NS" if col == "Valor máximo"
                  col = "Valor máximo NdS" if col == nil
                end
                
                # HACK: Para poder poner los valores correspondientes tomando en cuenta los encabezados
                if hoja.name == "c_TasaOCuota"
                  col = "maximo" if col == nil 
                  col = "minimo" if col == "c_TasaOCuota" 
                end
              
                next if col == nil
                # Si el nombre de la columna es el mismo que la hoja entonces es el "id" del catálogo
                col = "id" if hoja.name.index(col.to_s) != nil
                nombre = col.to_s
                # Convertimos a ASCII valido
                nombre = nombre.encode(Encoding.find('ASCII'), @encoding_options)
                # Convertimos la primer letra a minuscula
                nombre[0] = nombre[0].chr.downcase
                # La convertimos a camelCase para seguir la guia de JSON de Google:
                # https://google.github.io/styleguide/jsoncstyleguide.xml
                nombre = nombre.gsub(/\s(.)/) {|e| $1.upcase}
              
                encabezados << nombre
              end
            
              next
            end    
          end


          # Solo procedemos si ya hubo encabezados
          if  encabezados.count > 0 then
            #puts encabezados.to_s
            # Si la columna es tipo fecha nos la saltamos ya que es probable
            # que sea el valor de la fecha de modificacion del catálogo
            next if row[0].class == Date 
            
            hash_renglon = Hash.new
            for k in 0..encabezados.count - 1
              next if encabezados[k].to_s == ""  
              if row[k].instance_of?(Spreadsheet::Formula) == true
                  valor = row[k].value
              else                              
                
                if row[k].class == Float 


                  title_regex = /^(c|C)_\w+/
                  if (title_regex.match(encabezados[k])) or encabezados[k] == 'id'
                    if hoja.name == "c_Impuesto"
                      valor = "%03d" % row[k].to_i                                             
                    else
                      valor = "%02d" % row[k].to_i                       
                    end
                  else
                    valor = row[k].to_f  
                    if valor % 1 == 0
                      valor = "%02d" % valor.to_i
                    end 
                    valor = valor.to_s
                    
                  end

                else

                  if row[k].class == Date
                    valor = row[k].strftime("%d-%m-%Y")
                  else
                    valor = row[k].to_s
                  end
                  
                end
              end

              #hack para poder construir nominas 
              if hoja.name == "c_TipoDeComprobante"
                if k == 3 and valor == ""
                  valor = hash_renglon[encabezados[k-1]]
                end
                if k == 2 and valor == "NS"
                  mycolumns = hoja.column(k)
                  counter_col = 0
                  mycolumns.each{
                    |cell|
                    if counter_col == j
                      valor = cell
                    end
                    counter_col += 1
                    
                  }
                end
                if k == 3 and valor == "NdS"
                  mycolumns = hoja.column(k)
                  counter_col = 0
                  mycolumns.each{
                    |cell|
                    if counter_col == j
                      valor = cell
                    end
                    counter_col += 1
                    
                  }
                end
              end
              hash_renglon[encabezados[k]] = valor
            end
            renglones_json << hash_renglon
            
          end  

          
        end 
      
        # Guardamos el contenido JSON
        if !en_partes || ultima_parte then 
          #puts "Escribiendo archivo JSON..."
          hoja.name.sub!(/(_Parte_\d+)$/, '') if ultima_parte
          File.open("#{tempdir}/#{final_dir}/#{hoja.name}.json","w") do |f|
            f.write(JSON.pretty_generate(renglones_json))
          end
          renglones_json = nil
          en_partes = false
          ultima_parte = false
          encabezados = Array.new
        end
      end
      pbar.finish()
      
  
     
      
      puts "Se finalizó creacion de JSONs en directorio: #{tempdir}"

    rescue => e
      puts "Error en generacion de JSONs: #{e.message}"
      raise
    end

    return true

  end





  def nueva_last(url_excel = @catalogos_url)
    url_excel = URI.parse(url_excel)
    new_last = nil
    _httpWork = Net::HTTP.start(url_excel.host) do
      |http|
      response = http.request_head(url_excel.path)
      new_last = response['Last-Modified']
    end
    return new_last
  end

  # Compara el eTag del .xls en la pagina del SAT con el @last_eTag
  # @param local_eTag [String] siempre intentara utilizar el @last_eTag a menos que se mande explicitamente un eTag, este se puede
  # obtener de @last_eTag en una iteracion previa del programa.
  # @param url_excel [String] el url donde el SAT tiene los catalogos, valor default @catalogos_url
  # @return [Bool] verdadero si los eTags son distintos, es decir, si hay una nueva version disponible.
  def nuevo_xls?(local_last = nil, url_excel = @catalogos_url)
    local_last = @local_last if local_last.nil?
    new_Last = nueva_last(url_excel)

    return new_Last != local_last

  end



  # Encapsula los demas metodos en una sola rutina
  # @param local_eTag [String] siempre intentara utilizar el @last_eTag a menos que se mande explicitamente un eTag, este se puede
  # obtener de @last_eTag en una iteracion previa del programa.
  # @param url_excel [String] el url donde el SAT tiene los catalogos, valor default @catalogos_url
  # @return [Bool] verdadero si no hubo ningun error.
  def main(url_excel = @catalogos_url)

    descargar(url_excel)
    procesar()
    
    return true
        
  end

end
  

