require 'minitest/autorun'
require 'catalogos_sat'

class CatalogosTest < Minitest::Test
  def test_urls
    myTest = Catalogos.new()
    assert(myTest.get_url_xls() == "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/documentos/catCFDI.xls")
    assert(myTest.get_url_html() == "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20_version3-3.htm")
  end

  def test_modulos
    myTest = Catalogos.new()
    assert(myTest.descargar)
    assert(myTest.procesar)
    assert(myTest.nuevo_xls? == false)    
    assert(myTest.nuevo_xls?("test"))
        
  end
  def test_main
    myTest = Catalogos.new()
    assert(myTest.main)
  end

  

end