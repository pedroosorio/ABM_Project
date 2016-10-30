include("ABM_BasicTypes.jl") #includes Symbol,Rule and Generic List types and Agent Related Data
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
  TempCell

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
