require 'primo'

ASS = %w(FF Ff ff)

module Probe
  def puffreduce(probs, rango)
    negos = probs.map{|p| 1-p}
    ixes = (0..(probs.size-1)).to_a
    sol = 0
    rango.each do |i|
      ixes.combination(i).each do |a1|
        b1 = ixes - a1
        sol += a1.map{|e| probs[e]}.reduce(:*) * b1.map{|e| negos[e]}.reduce(:*)
      end
    end
    sol
  end

  def at_least_n_AaBb(probs, n)
    probs.reduce(:*) + puffreduce(probs, (n..((2**K)-1)))
  end

  def at_most_n_AaBb(probs, n)
    probs.reduce(1){|tot, p| tot *= (1-p)} + puffreduce(probs, (1..(n-1)))
  end

  def solve_for_at_least_n(probs, n)
    (n < probs.size/2) ?  (1 - at_most_n_AaBb(probs, n)) : at_least_n_AaBb(probs, n)
  end
end


class Genotype < RandomVar
  def initialize(name)
    super(card: 3, name: name, ass: ASS)
  end
end

class Person
  attr_accessor :name, :gen, :dad, :gnF

  def initialize(name)
    self.name = name
    self.gen = Genotype.new(name)
    self.dad = nil
    self.gnF = nil
  end

  def son_of(daddy)
    self.dad = daddy
    self
  end

  def compute_factors
    self.gnF = (dad ? gen_parent_factor : gen_prob_factor)
  end

  def gen_prob_factor # FF Ff ff
    Factor.new(vars: [gen], vals: [1.0, 2.0, 1.0])
  end

  def gen_parent_factor
    mg = %w(F f)
    vals = ASS.map do |kg|
      ASS.map do |dg|
        dg.chars.product(mg).map(&:sort).map(&:join).count(kg).to_f
      end
    end
    Factor.new(vars: [dad.gen, gen], vals: vals)
  end

  def observe_gen(ass)
    gnF.reduce(gen => ass).normalize_values
  end
end

class Family
  include Probe
  attr_accessor :members, :clique_tree, :k

  def initialize(k_levels)
    self.k = k_levels
    tom = Person.new('0')
    self.members = [tom]
    last_level = [tom]
    id = 1
    (1..k_levels).each do |level|
      temp = []
      last_level.each do |dad|
        2.times do
          guy = Person.new("#{id}_#{level}").son_of(dad)
          members << guy
          temp << guy
          id += 1
        end
      end
      last_level = temp
    end
  end

  def initialize_factors
    members.each(&:compute_factors)
  end

  def setup
    all_factors = members.map(&:gnF).flatten
    self.clique_tree = CliqueTree.new(*all_factors)
    clique_tree.calibrate
  end

  def [](name)
    members.find { |p| p.name == name }
  end

  def last_generation
    members.select { |guy| guy.name =~ /_#{k}$/ }
  end

  def probs_AaBb(array_of_members, ass)
    array_of_members.map { |guy| clique_tree.query(guy.gen, ass)**2 }
  end
end

######################################################################
##### CREATE A FAMILY AS A BINARY TREE AND CALIBRATE CLIQUE TREE #####
######################################################################

G = 'FF'  # The genotype we are looking for
K = 4     # number of levels of the binary tree
N = 1     # compute the prob of at least N people with genotype G

smiths = Family.new(K)
smiths.initialize_factors
smiths.setup

generation_probs = smiths.probs_AaBb(smiths.last_generation, G)
p generation_probs
puts "Prob of at least #{N} people of last generation being #{G}: " +
     "#{100 * smiths.solve_for_at_least_n(generation_probs, N)} %"
puts '-'*40

######################################################################
##### ...AND NOW WE HAVE FUN SCREWING UP OBSERVATIONS            #####
######################################################################

GX = 'ff'
smiths = Family.new(K)
smiths.initialize_factors

# lets make a random guy in each generation to have genotype GX
(1..(K-1)).each do |n|
  first_g = smiths.members
                  .select { |guy| guy.name =~ /_#{n}$/ }
                  .sample.observe_gen(GX)
end

smiths.setup

generation_probs = smiths.probs_AaBb(smiths.last_generation, G)
p generation_probs
puts "Prob of at least #{N} people of last generation being #{G}: " +
     "#{100 * smiths.solve_for_at_least_n(generation_probs, N)} %"

# The key is that FOR 'Ff' it doesn't matter who is the father: FF Ff or ff

# FF x Ff => FF Ff FF Ff
# 2xFF 2xFf 0xff => Prob of Ff is 0.5

# Ff x Ff => FF Ff fF ff
# 1xFF 2xFf 1xff => Prob of Ff is also 0.5

# ff x Ff => fF ff fF ff
# 0xFF 2xFf 2xff => Prob of Ff is again the same 0.5

# It would be different if we were looking for the ff or FF genotype

