Create::Rule.new(/./){|amp|
  amp.value_method = :dummy_method
}
