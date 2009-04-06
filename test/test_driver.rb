$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"

require 'comp_tree'
require 'test/unit'
require 'benchmark'

TREE_GENERATION_DATA = {
  :level_range => 1..4,
  :children_range => 1..6,
  :thread_range => 1..6,
  :drain_iterations => 0,
}

module CompTree
  module TestCommon
    if ARGV.include?("--bench")
      def separator
        puts
        puts "-"*60
      end

      def bench_output(desc = nil, stream = STDOUT, &block)
        if desc
          stream.puts(desc)
        end
        if block
          expression = block.call
          result = eval(expression, block.binding)
          stream.printf("%-16s => %s\n", expression, result.inspect)
          result
        end
      end
    else
      def separator() end
      def bench_output(desc = nil, stream = STDOUT, &block) end
    end
  end

  module TestBase
    include TestCommon

    def test_1_syntax
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
        
        assert_equal((2 + 5)*(3 + 5) - 7, driver.compute(:area, 6))
      }
    end

    def test_2_syntax
      CompTree.build { |driver|
        driver.define_area(:width, :height, :offset) { |width, height, offset|
          width*height - offset
        }
        
        driver.define_width(:border) { |border|
          2 + border
        }
        
        driver.define_height(:border) { |border|
          3 + border
        }
        
        driver.define_border {
          5
        }
        
        driver.define_offset {
          7
        }
        
        assert_equal((2 + 5)*(3 + 5) - 7, driver.compute(:area, 6))
      }
    end

    def test_3_syntax
      CompTree.build { |driver|
        driver.define_area :width, :height, :offset, %{
          width*height - offset
        }
        
        driver.define_width :border, %{
          2 + border
        }
        
        driver.define_height :border, %{
          3 + border
        }
        
        driver.define_border %{
          5
        }
        
        driver.define_offset %{
          7
        }

        assert_equal((2 + 5)*(3 + 5) - 7, driver.compute(:area, 6))
      }
    end

    def test_thread_flood
      (1..200).each { |num_threads|
        CompTree.build { |driver|
          drain = lambda { |*args|
            1.times { }
          }
          driver.define_a(:b, &drain)
          driver.define_b(&drain)
          driver.compute(:a, num_threads)
        }
      }
    end

    def test_sequential
      (1..50).each { |num_threads|
        [1, 2, 3, 20, 50].each { |num_nodes|
          CompTree.build { |driver|
            driver.define(:root) { true }
            (1..num_nodes).each { |n|
              if n == 0
                driver.define("a#{n}".to_s, :root) { true }
              else
                driver.define("a#{n}".to_s, "a#{n-1}".to_s) { true }
              end
            }
            driver.compute(:root, num_threads)
          }
        }
      }
    end

    def test_malformed
      CompTree.build { |driver|
        assert_raise(CompTree::ArgumentError) {
          driver.define {
          }
        }
        assert_raise(CompTree::RedefinitionError) {
          driver.define(:a) {
          }
          driver.define(:a) {
          }
        }
        assert_raise(CompTree::ArgumentError) {
          driver.define(:b) {
          }
          driver.compute(:b, 0)
        }
        assert_raise(CompTree::ArgumentError) {
          driver.define(:c) {
          }
          driver.compute(:c, -1)
        }
      }
    end

    def test_exception_in_compute
      test_error = Class.new(RuntimeError)
      CompTree.build { |driver|
        driver.define_area(:width, :height, :offset) { |width, height, offset|
          width*height - offset
        }
        
        driver.define_width(:border) { |border|
          2 + border
        }
        
        driver.define_height(:border) { |border|
          3 + border
        }
        
        driver.define_border {
          raise test_error
        }
        
        driver.define_offset {
          7
        }
        
        assert_raise(test_error) {
          driver.compute(:area, 6)
        }
      }
    end

    def test_method_missing_intact
      assert_raise(NoMethodError) {
        CompTree.build { |driver|
          driver.junk
        }
      }
    end

    def test_node_subclass
      subclass = Class.new(CompTree::Node) {
        def stuff
          "--data--"
        end
      }
      CompTree.build(:node_class => subclass) { |driver|
        driver.define(:a) {
        }
        assert_equal("--data--", driver.nodes[:a].stuff)
      }
    end

    def generate_comp_tree(num_levels, num_children, drain_iterations)
      CompTree.build { |driver|
        root = :aaa
        last_name = root
        pick_names = lambda { |*args|
          (0..rand(num_children)).map {
            last_name = last_name.to_s.succ.to_sym
          }
        }
        drain = lambda { |*args|
          drain_iterations.times {
          }
        }
        build_tree = lambda { |parent, children, level|
          #trace "building #{parent} --> #{children.join(' ')}"
          
          driver.define(parent, *children, &drain)

          if level < num_levels
            children.each { |child|
              build_tree.call(child, pick_names.call, level + 1)
            }
          else
            children.each { |child|
              driver.define(child, &drain)
            }
          end
        }
        build_tree.call(root, pick_names.call, drain_iterations)
        driver
      }
    end

    def run_generated_tree(args)
      args[:level_range].each { |num_levels|
        args[:children_range].each { |num_children|
          separator
          bench_output {%{num_levels}}
          bench_output {%{num_children}}
          driver = generate_comp_tree(
            num_levels,
            num_children,
            args[:drain_iterations])
          args[:thread_range].each { |threads|
           bench_output {%{threads}}
            2.times {
              driver.reset(:aaa)
              result = nil
              bench = Benchmark.measure {
                result = driver.compute(:aaa, threads)
              }
              bench_output bench
              assert_equal(result, args[:drain_iterations])
            }
          }
        }
      }
    end

    def test_generated_tree
      run_generated_tree(TREE_GENERATION_DATA)
    end
  end

  class TestCore < Test::Unit::TestCase
    include TestBase
  end
  
  class TestDrainer < Test::Unit::TestCase
    include TestCommon

    def drain
      5000.times { }
    end
    
    def run_drain(threads)
      CompTree.build { |driver|
        func = lambda { |*args|
          drain
        }
        driver.define_area(:width, :height, :offset, &func)
        driver.define_width(:border, &func)
        driver.define_height(:border, &func)
        driver.define_border(&func)
        driver.define_offset(&func)
        bench_output "number of threads: #{threads}"
        bench = Benchmark.measure { driver.compute(:area, threads) }
        bench_output bench
      }
    end

    def each_drain
      (1..10).each { |threads|
        yield threads
      }
    end

    def test_drain
      separator
      each_drain { |threads|
        run_drain(threads)
      }
    end
  end
end
