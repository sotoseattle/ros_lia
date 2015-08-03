# PHENO_STATS = { 'FF' => 0.8, 'Ff' => 0.6, 'ff' => 0.1 }
# GEN_STATS = { 'F' => 0.1, 'f' => 0.9 }

require 'primo'

class Genotype < RandomVar
  def initialize(name)
    super(card: 3, name: name, ass: %w(FF Ff ff))
  end
end

class Family
  attr_reader :members

  def initialize(names)
    @members = names.map { |name| Person.new(name) }
  end

  def [](name)
    members.find { |p| p.name == name }
  end
end

class Person
  attr_accessor :name, :gen, :phn, :phF, :dad, :mom, :gnF

  def initialize(name)
    @name = name
    @gen = Genotype.new(name)
    @dad = nil
    @mom = nil
    @gnF = nil
  end

  def son_of(daddy, mommy)
    self.dad, self.mom = daddy, mommy
  end

  def compute_factors
    self.gnF = ((dad && mom) ? gen_parents_factor : gen_prob_factor)
  end

  def gen_prob_factor # FF Ff ff
    Factor.new(vars: [gen], vals: [0.25, 0.5, 0.25])
  end

  def gen_parents_factor
    vals = []
    %w(FF Ff ff).each do |kg|
      %w(FF Ff ff).each do |dg|
        %w(FF Ff ff).each do |mg|
          vals << dg.chars.product(mg.chars).map(&:sort).map(&:join).count(kg)
        end
      end
    end
    Factor.new(vars: [dad.gen, mom.gen, gen], vals: vals)
  end

  def observe_gen(ass)
    gnF.reduce(gen => ass).normalize_values
  end
end

class CTFamily < Family
  attr_accessor :clique_tree

  def setup
    all_factors = members.map(&:gnF).flatten
    @clique_tree = CliqueTree.new(*all_factors)
    clique_tree.calibrate
  end
end


####################################################################
#########################   TESTING   ##############################
####################################################################

smiths = CTFamily.new(%w(Tom sp0 Pep Eva sp1 sp2 Luc Mas Oli Fua))

smiths['Pep'].son_of(smiths['Tom'], smiths['sp0'])
smiths['Eva'].son_of(smiths['Tom'], smiths['sp0'])

smiths['Luc'].son_of(smiths['Pep'], smiths['sp1'])
smiths['Mas'].son_of(smiths['Pep'], smiths['sp1'])
smiths['Oli'].son_of(smiths['Eva'], smiths['sp2'])
smiths['Fua'].son_of(smiths['Eva'], smiths['sp2'])

smiths.members.map(&:compute_factors)
smiths.setup

%w(Tom Pep Eva Luc Mas Oli Fua).each do |name|
  random_var = smiths[name].gen
  k = smiths.clique_tree.query(random_var, 'Ff')
  puts "#{name} p(Ff) = #{k}"
end

class Integer
  def factorial_iterative
    f = 1; for i in 1..self; f *= i; end; f
  end
  alias :factorial :factorial_iterative
end

k = 5
n = 8

k1 = 2**k

# prob_kid_Aa = smiths.clique_tree.query(smiths['Fua'].gen, 'Ff')
prob_kid_Aa = 0.5
prob_kid_AaBb = prob_kid_Aa ** 2
prob_no_Ff = (1 - prob_kid_AaBb )**k1

sol = 0
(0..(n-1)).each do |o|
  number_combinations = k1.factorial/(o.factorial * (k1-o).factorial)
  sol += (prob_kid_AaBb**o * (1 - prob_kid_AaBb)**(k1-o)) * number_combinations
end
puts "SOLUTION: #{(1 - sol) * 100}"

