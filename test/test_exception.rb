$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"

require 'comp_tree'
require 'test/unit'

module CompTree
  class TestRaises < Test::Unit::TestCase
    class CompTreeTestError < StandardError ; end

    def test_exception
      [true, false].each { |define_all|
        error = (
          begin
            CompTree.build { |driver|
              driver.define(:area, :width, :height, :offset) {
                |width, height, offset|
                width*height - offset
              }
              
              driver.define(:width, :border) { |border|
                2 + border
              }

              driver.define(:height, :border) { |border|
                3 + border
              }
              
              if define_all
                driver.define(:border) {
                  raise CompTreeTestError
                }
              end
              
              driver.define(:offset) {
                7
              }
        
              driver.compute(:area, 99) 
            }
            nil
          rescue => e
            e
          end
        )

        if define_all
          assert_block { error.is_a? CompTreeTestError }
        else
          assert_block { error.is_a? CompTree::NoFunctionError }
        end
      }
    end
  end
end 
