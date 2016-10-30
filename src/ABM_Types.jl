export List
export Symbol
export Rule
export StandardPriceCell
export ProductOffer
export BList_Cell
export CreditContract

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

type CreditContract
  Amount::Float64
  InterestRates::Float64
  CreditPayTime::Int64 #Number of periods that the client has to clear out the credit
  AmountPaid::Float64
  ClientID::Int64
  LenderID::Int64

  function CreditContract(amount,interest_rates,pay_time,client_id,lender_id)
    this = new();
    this.Amount = amount;
    this.InterestRates = interest_rates;
    this.CreditPayTime = pay_time;
    this.AmountPaid = 0.0;
    this.ClientID = client_id;
    this.LenderID = lender_id;
    return this;
  end
end

###################################################################################
###################################################################################
#Defining Product Offer type
type ProductOffer
  Producer::Int64
  Units::Int64
  OrderedUnits::Int64
  UnitPrice::Float64
end
###################################################################################
###################################################################################

###################################################################################
###################################################################################
#Defining a Cell of the B List
type BList_Cell
  Product::AbstractString
  Producers::List{Int64}
  Offers::List{ProductOffer}
  AvgPriceSold::Float64
  Remaining::Int64

  function BList_Cell(Product_)
    this = new()
    this.Product = Product_
    this.Producers = List{Int64}(Int64)
    this.Offers = List{ProductOffer}(ProductOffer)
    this.AvgPriceSold = 0.0
    this.Remaining = 0
    return this
  end
end
###################################################################################
###################################################################################
#Initialization of B List
function InitB(B::List{BList_Cell}, V::List{List{Rule}})
  b_already = false #To flag the existance of the consequent in the B list

  for i=1:length(V.vec) #Run through every producer set of rules
    for j=1:length(V.vec[i].vec) #Run through every rule of producer i

      b = V.vec[i].vec[j].Consequent.Symbol   #consequent - string b
      _type = V.vec[i].vec[j].Type    #type a,b,c or d

      if(_type=="a" || _type=="c") #If the b product is saleable
        if(length(B.vec)==0) #B List is empty, so b will be added as the producer
          TempCell = BList_Cell(b) #Create a Cell where the product is b
          TempCell.Producers.addContent(i) #Add the producer to the salers of that product b
          B.addContent(TempCell)
        else
          for cell=1:length(B.vec) #Search for the existance of the product in the B List
            if(b==B.vec[cell].Product) #If the product already exists, flag it
              b_already = true
              for prod=1:length(B.vec[cell].Producers.vec)#Search for the producer in that product producer list
                if(B.vec[cell].Producers.vec[prod]==i)
                  break
                end
                B.vec[cell].Producers.addContent(i) #Add this producer as a producer of product b
                break
              end
              break
            end
          end
          if(b_already)
            b_already = false
          else
           TempCell = BList_Cell(b) #Create a Cell where the product is b
           TempCell.Producers.addContent(i) #Add the producer to the salers of that product b
           B.addContent(TempCell)
          end
        end
      end
    end
  end

end
###################################################################################
###################################################################################
function CheckBList(B::List{BList_Cell})
  println("↑ Displaying Current B List ...")
  for cell=1:length(B.vec)
    println("► Product ",B.vec[cell].Product," Produced by:")
    for prod=1:length(B.vec[cell].Producers.vec)
      println("    ♦ Producer ",B.vec[cell].Producers.vec[prod])
      println("► Average Price: ",B.vec[cell].AvgPriceSold)
      println("► Remaining Items: ",B.vec[cell].Remaining)
    end
    #print the existing offers
    for offer=1:length(B.vec[cell].Offers.vec)
      println(" ♦ ",B.vec[cell].Offers.vec[offer].Units, " @ "
              ,B.vec[cell].Offers.vec[offer].UnitPrice, " by Producer",B.vec[cell].Offers.vec[offer].Producer)
    end
    println();
  end

end
###################################################################################
###################################################################################
