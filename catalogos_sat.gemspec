Gem::Specification.new do |s|
    s.name        = 'catalogos_sat'
    s.version     = '0.0.7'
    s.date        = '2017-11-07'
    s.summary     = "Script para generar JSONS de catalogos del SAT"
    s.description = "Utilerias para generar JSONS de los catalogos del SAT en Mexico. Descarga el archivo .xls que el sat proporciona y parsea las columnas y filas"
    s.authors     = ["BambuCode", "Ricardo Trevizo"]
    s.email       = 'hola@bambucode.com'
    s.files       = ["lib/catalogos_sat.rb"]
    s.homepage    =
      'http://rubygems.org/gems/catalogos_sat'
    s.license       = 'MIT'
    s.add_runtime_dependency "ruby-progressbar", "~> 1.9"
    s.add_runtime_dependency "spreadsheet", "~> 1.1"
  end
