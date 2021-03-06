require File.expand_path(File.dirname(__FILE__)) + '/comp_tree_test_base'

class BasicTest < CompTreeTest
  def test_define
    (0..20).each { |threads|
      CompTree.build { |driver|
        driver.define(:area, :width, :height, :offset) { |width, height, offset|
          width*height - offset
        }
        
        driver.define(:width, :border) { |border|
          2 + border
        }
        
        driver.define(:height, :border) { |border|
          3 + border
        }
        
        driver.define(:border) {
          5
        }
        
        driver.define(:offset) {
          7
        }
        
        assert_equal((2 + 5)*(3 + 5) - 7, driver.compute(:area, threads))
      }
    }
  end

  def test_already_computed
    [nil, false, true, 33].each { |result|
      CompTree.build { |driver|
        driver.define(:a) { result }
        (0..6).each { |n|
          assert_equal(result, driver.compute(:a, n))
        }
      }
    }
  end

  def test_threads_opt
    (0..20).each { |threads|
      CompTree.build do |driver|
        driver.define(:a) { 33 }
        assert_equal(33, driver.compute(:a, threads))
      end
    }
  end

  def test_malformed
    CompTree.build { |driver|
      assert_raises(ArgumentError) {
        driver.define {
        }
      }
      error = assert_raises(CompTree::RedefinitionError) {
        driver.define(:a) {
        }
        driver.define(:a) {
        }
      }
      assert_equal "attempt to redefine node `:a'", error.message
      assert_equal :a, error.node_name
    }
  end

  def test_exception_in_compute
    test_error = Class.new(RuntimeError)
    CompTree.build { |driver|
      driver.define(:area, :width, :height, :offset) { |width, height, offset|
        width*height - offset
      }
      
      driver.define(:width, :border) { |border|
        2 + border
      }
      
      driver.define(:height, :border) { |border|
        3 + border
      }
      
      driver.define(:border) {
        raise test_error
      }
      
      driver.define(:offset) {
        7
      }
      
      (0..20).each { |n|
        assert_raises(test_error) {
          driver.compute(:area, n)
        }
        driver.reset(:area)
      }
    }
  end

  def test_node_subclass
    data = Object.new
    subclass = Class.new(CompTree::Node) {
      define_method :stuff do
        data
      end
    }
    CompTree.build(:node_class => subclass) { |driver|
      driver.define(:a) { }
      assert_equal(data, driver.nodes[:a].stuff)
    }
  end

  def test_non_symbols
    width_id = Object.new
    height_id = 272727
    (0..6).each { |threads|
      CompTree.build { |driver|
        driver.define("area", width_id, height_id, :offset) {
          |width, height, offset|
          width*height - offset
        }
          
        driver.define(width_id, :border) { |border|
          2 + border
        }
          
        driver.define(height_id, :border) { |border|
          3 + border
        }
          
        driver.define(:border) {
          5
        }
          
        driver.define(:offset) {
          7
        }
          
        assert_equal((2 + 5)*(3 + 5) - 7, driver.compute("area", threads))
      }
    }
  end

  def test_node_name_equality_comparison
    CompTree.build { |driver|
      driver.define("hello") { }
      assert_raises(CompTree::RedefinitionError) {
        driver.define("hello") { }
      }
    }
  end
  
  def test_result_variety
    [true, false, nil, Object.new, 33].each { |result|
      (0..20).each { |threads|
        CompTree.build { |driver|
          driver.define(:area, :width, :height, :offset) {
            |width, height, offset|
            result
          }
          
          driver.define(:width, :border) { |border|
            result
          }
          
          driver.define(:height, :border) { |border|
            result
          }
          
          driver.define(:border) {
            result
          }
          
          driver.define(:offset) {
            result
          }
          
          assert_equal(result, driver.compute(:area, threads))
        }
      }
    }
  end
end
