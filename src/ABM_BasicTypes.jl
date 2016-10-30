export List
export Symbol
export Rule
export StandardPriceCell


type List{T}
  vec::Vector{T}
  addContent::Function
  deleteList::Function
  deleteContent::Function
  copyList::Function
  getSize::Function

  function List(Type)
    this = new()
    this.vec = Type[]

    this.copyList = function(cp::List{T})
      for i=1:length(cp.vec)
        push!(this.vec, cp.vec[i])
      end
    end

    this.addContent = function(append::T)
      push!(this.vec, append)
    end

    this.deleteContent = function(index::Int)
      if index > 0 && index <= length(this.vec)
        deleteat!(this.vec, index)
      end
    end

    this.deleteList = function()
      if length(this.vec) != 0
        for i=1:length(this.vec)
          deleteat!(this.vec, 1)
        end
      end
    end

    this.getSize = function()
      return length(this.vec)
    end

    return this
  end
end


type Symbol
  Symbol::AbstractString               # Strings of simbols (Unicode)
  Amount::Int64                # Quantity
  announcedToProduction::Int64 #Amount to produce announced product
end

type StandardPriceCell
  Symbol::AbstractString               # Strings of simbols (Unicode)
  PriceList::List{Float64}                # Quantity

  function StandardPriceCell(symb,pricelist::List{Float64})
    this = new()
    this.Symbol = symb;
    this.PriceList = List{Float64}(Float64);
    this.PriceList.copyList(pricelist);
    return this;
  end
end

type Rule
  Antecedent::List{Symbol}     # A - the producer's copy of the antecendent multi-set
  Consequent::Symbol            # b - the producer's copy of the consequent string
  y::Int64                     # yA -> y(qb)
  Type::AbstractString          # a -> Possible&Saleable b -> Possible&Unsaleable c -> Necessary&Saleable d -> Necessary&Unsaleable
  Ymin::Int64                  # Ymin - minimum number of strings that the rule must produce in a k period
  YnomList::List{Int64}        # YnomList - Nominal values are no longer expressed by Ynom, but are a function of period k
  Ymax::Int64                  # Ymax - maximal number of strings that the rule can produce in a period k
  antecedentsReady::Bool

  function Rule(Ant, Cons, y_, Type_, Ymin_, Ynom_, Ymax_,ynomList_)
    this = new()
    this.Antecedent = List{Symbol}(Symbol)
    this.Antecedent.copyList(Ant)
    this.Consequent = Cons
    this.y = y_
    this.Type = Type_
    this.Ymin = Ymin_
    this.Ymax = Ymax_
    this.YnomList = List{Int64}(Int64);
    this.YnomList.copyList(ynomList_);
    this.antecedentsReady = false
    return this
  end
end

type ControllerGoal
  Symbol::AbstractString
  Ymin::Int64
  Ynom::Int64
  function ControllerGoal(symb, min, nom)
    this = new()
    this.Symbol = symb;
    this.Ymin = min;
    this.Ynom = nom;
    return this;
  end
end
