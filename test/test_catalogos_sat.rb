require 'minitest/autorun'
require 'catalogos_sat'

class CatalogosTest < Minitest::Test

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