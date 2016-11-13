include("ABM_Types.jl") #includes Symbol,Rule and Generic List types
using JSON

###################################################################################
###################################################################################
#CONTROLLER AGENT

############### CONTROLLER TYPE ###############
###############################################
type Controller
  taxPercentage::Float64 # Taxes could be a list of taxes, indexed by Producer
  Goals::List{ControllerGoal}
  Prices::List{Float64}    #

  function Controller(tax = 1.0)
    this = new()
    this.taxPercentage = tax
    this.Goals = List{ControllerGoal}(ControllerGoal)
    this.Prices = List{Float64}(Float64)
    return this
  end
end
###############################################
###############################################

############### INITC FUNCTION ################
###############################################
function InitC(C::Controller,Taxes,Configuration,systemConfigFileName)
  C.taxPercentage = Taxes;
  # looks for controller goals in JSON format in Agents.json file
  println("↓ Parsing Controller Data ...")
  try
    CONTROLLER_DATA = Configuration["Controller"]
    try
      CONTROLLER_GOALS = CONTROLLER_DATA["ControllerGoals"]
      for tuple in CONTROLLER_GOALS
        C.Goals.addContent(ControllerGoal(tuple["Symbol"], tuple["Min"],tuple["Nom"],tuple["Max"],tuple["Price"]))
        C.Prices.addContent(tuple["Price"])
      end
      try
        CONTROLLER_PARAMETERS = CONTROLLER_DATA["ControllerParameters"]
        for tuple in CONTROLLER_PARAMETERS
          C.taxPercentage = tuple["TaxingPercentage"];
        end
      catch error
        if isa(error, KeyError)
          println("No ControllerParameters or Errors at ",systemConfigFileName," ... exiting")
          quit()
        end
      end
    catch error
      if isa(error, KeyError)
        println("No ControllerGoals or Error at ",systemConfigFileName," ... exiting")
        quit()
      end
    end
  catch error
    if isa(error, KeyError)
    println("No Controller data in ",systemConfigFileName," ... exiting")
    quit()
    end
  end

  #Correct possible mistakes in percentage settings
  if(C.taxPercentage<0.0) C.taxPercentage = 0.0 end
  if(C.taxPercentage>1.0) C.taxPercentage = 1.0 end

  println("▬ Controller Successfuly Initialized\n")
end
###############################################
###############################################

###################################################################################
###################################################################################


###################################################################################
###################################################################################
#PRODUCER AGENT

type Producer

  ########### DATA #############
  ##############################
  Numeraire::Float64 #Current numeraire of the agent
  Credits::List{CreditContract} #List of credits contracted
  Assets::Float64  #Assets as numeraire
  Liabilities::Float64  #Liabilities as numeraire

  InputStore::List{Symbol} # Input store of the agent
  OutputStore::List{Symbol} # Output store of the agent

  Enabled::Bool # Flags if the agent is alive or not
  ID::Int64 # ID of the agent
  Internal::Bool # Sector of operation of the agent
  numeraireToBeTaxed::Float64 #Numeraire to be taxed (profit)
  ##############################
  ##############################

  ######### FUNCTIONS ##########
  ##############################
  existsInInputStore::Function
  existsInInputStoreItem::Function
  getSymbolAmount::Function

  deletePrecedentInputStore::Function
  deleteOutputStore::Function
  addConsequentOutputStore::Function

  atomicSale::Function
  setToProduction::Function
  addConsequentInputStore::Function
  transferToInputStore::Function
  keepItems::Function
  ##############################
  ##############################

  function Producer(Numeraire = 0.0,internal=true, id_ = 0)
    this = new()
    this.Numeraire = Numeraire
    this.InputStore = List{Symbol}(Symbol)
    this.OutputStore = List{Symbol}(Symbol)
    this.Credits = List{CreditContract}(CreditContract)
    this.Enabled = true
    this.ID = id_
    this.Internal = internal

    ######################################################
    ######################################################
    this.existsInInputStore = function(pre)
      Amounts_ = List{Int64}(Int64)
      Amounts_.deleteList();
      searchedItems = length(pre.vec)
      foundItems = 0


      if(length(pre.vec)==1 && (pre.vec[1].Symbol=="*")) #infinite source
        return true,Amounts_;
      end

      for preprod = 1:length(pre.vec)
        for instore = 1:length(this.InputStore.vec)
          if(pre.vec[preprod].Symbol ==  this.InputStore.vec[instore].Symbol
             && pre.vec[preprod].Amount <= this.InputStore.vec[instore].Amount)
            Amounts_.addContent(trunc(Int64,this.InputStore.vec[instore].Amount/pre.vec[preprod].Amount))
            foundItems += 1
          end
        end
      end

      if(foundItems==searchedItems)
        return true,Amounts_;
      else
        return false,Amounts_;
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.existsInInputStoreItem = function(symbol,amount)
      quant = 0;
      hasItem = false
      for instore = 1:length(this.InputStore.vec)
        if(this.InputStore.vec[instore].Symbol ==  symbol)
          quant = this.InputStore.vec[instore].Amount-this.InputStore.vec[instore].announcedToProduction;
          if(quant >= amount)
            hasItem = true
            break
          end
        end
      end

      if(hasItem==true)
        return true
      else
        return false
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.getSymbolAmount = function(symbol)
      quantityFound = 0;

      for instore = 1:length(this.InputStore.vec)
        if(this.InputStore.vec[instore].Symbol ==  symbol)
          quantityFound += this.InputStore.vec[instore].Amount-this.InputStore.vec[instore].announcedToProduction;
        end
      end

      #println(this.ID, "still has $quantityFound items of $symbol")
      return quantityFound;
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.deletePrecedentInputStore = function(pre,quant)
      if(pre.vec[1].Symbol=="*" && length(pre.vec)==1)
        return 0
      end

      for preitem = 1:length(pre.vec)
        for prod=1:length(this.InputStore.vec)
          if(this.InputStore.vec[prod].Symbol==pre.vec[preitem].Symbol)

            this.InputStore.vec[prod].Amount -= pre.vec[preitem].Amount*quant
            if(this.InputStore.vec[prod].Amount == 0)
              this.InputStore.deleteContent(prod)
            end
            break
          end
        end
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.deleteOutputStore = function(item,quant)
      this.OutputStore.vec[item].Amount -= quant
      if(this.OutputStore.vec[item].Amount == 0)
        this.OutputStore.deleteContent(item)
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.setToProduction = function(Rules,item,quant)
      for rule=1:length(Rules.vec[this.ID].vec)
        if(Rules.vec[this.ID].vec[rule].Consequent.Symbol == item)
          pre = Rules.vec[this.ID].vec[rule].Antecedent
          for preprod=1:length(pre.vec)
            for prod=1:length(this.InputStore.vec)
              if(this.InputStore.vec[prod].Symbol==pre.vec[preprod].Symbol)
                this.InputStore.vec[prod].announcedToProduction = quant*pre.vec[preprod].Amount;
                #println("Tagged ",quant*pre.vec[preprod].Amount," items of ",pre.vec[preprod].Symbol," to Production")
              end
            end
          end
        end
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.addConsequentInputStore = function(consq,quant)
      product_found = false
      for prod=1:length(this.InputStore.vec)
        if(consq.Symbol==this.InputStore.vec[prod].Symbol)
          this.InputStore.vec[prod].Amount += consq.Amount*quant
          product_found = true
        end
      end

      if(!product_found)
        this.InputStore.addContent(Symbol(consq.Symbol,consq.Amount*quant))
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.transferToInputStore = function(symbol,quant)
      product_found = false
      for prod=1:length(this.OutputStore.vec)
        if(this.OutputStore.vec[prod].Symbol==symbol)
          this.OutputStore.vec[prod].Amount -= quant
          if(this.OutputStore.vec[prod].Amount == 0)
            this.OutputStore.deleteContent(prod)
          end
          break
        end
      end

    for prod=1:length(this.InputStore.vec)
        if(symbol==this.InputStore.vec[prod].Symbol)
          this.InputStore.vec[prod].Amount += quant
          product_found = true
        end
      end
      if(!product_found)
        this.InputStore.addContent(Symbol(symbol,quant,0))
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.keepItems = function(pre,consq,quant)
      product_found = false
      this.deletePrecedentInputStore(pre,quant);

      for prod=1:length(this.InputStore.vec)
          if(consq.Symbol==this.InputStore.vec[prod].Symbol)
            this.InputStore.vec[prod].Amount += quant
            product_found = true
          end
      end
      if(!product_found)
          this.InputStore.addContent(Symbol(consq.Symbol,quant,0))
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.addConsequentOutputStore = function(consq,quant)
      product_found = false
      for prod=1:length(this.OutputStore.vec)
        if(consq.Symbol==this.OutputStore.vec[prod].Symbol)
          this.OutputStore.vec[prod].Amount += consq.Amount*quant
          product_found = true
        end
      end

      if(!product_found)
        this.OutputStore.addContent(Symbol(consq.Symbol,consq.Amount*quant,0))
      end
    end
    ######################################################
    ######################################################

    ######################################################
    ######################################################
    this.atomicSale = function(Rules,Producers,consq,quant,producer,System,period) #this intends to an agent buy quant times the
      #consq item, by request, atomically
      if(producer==0) #This is the controller
        #println("Bought ",quant," item of ", consq," from Producer ",this.ID)
        @printf(f,"buy_%s(6,%d)=%d%s",consq,period,quant,"\n"); #Controller index must be 6 because Scilab does not allow for 0
        #@printf(f,"sale_%s(%d,%d)=%d%s",consq,this.ID,period,quant,"\n");
        for rule=1:length(Rules.vec[this.ID].vec) #Remove the desired precedents
          if(Rules.vec[this.ID].vec[rule].Consequent.Symbol == consq)
            pre = Rules.vec[this.ID].vec[rule].Antecedent
            this.deletePrecedentInputStore(pre,quant)
          end
        end
        paid = quant*System.getStandardPrice(consq,period);
        owner = this.ID;
        #The controller must pay the producer for the products
        #println("Controller Paying $paid to $owner for $quant items of $consq")
        this.Numeraire += paid;
        this.numeraireToBeTaxed += paid;
      else
        #println("Bought ",quant," item of ", consq.Symbol," from Producer ",this.ID)
        @printf(f,"buy_%s(%d,%d)=%d%s",consq.Symbol,Producers.vec[producer].ID,period,quant,"\n");
        #@printf(f,"sale_%s(%d,%d)=%d%s",consq.Symbol,this.ID,period,quant,"\n");
        for rule=1:length(Rules.vec[this.ID].vec) #Remove the desired precedents
          if(Rules.vec[this.ID].vec[rule].Consequent.Symbol == consq.Symbol)
            pre = Rules.vec[this.ID].vec[rule].Antecedent
            this.deletePrecedentInputStore(pre,quant)
          end
        end

        product_found = false
        for prod=1:length(Producers.vec[producer].InputStore.vec)
          if(consq.Symbol==Producers.vec[producer].InputStore.vec[prod].Symbol)
            Producers.vec[producer].InputStore.vec[prod].Amount += quant
            product_found = true
          end
        end

        if(!product_found)
          Producers.vec[producer].InputStore.addContent(Symbol(consq.Symbol,quant,0))
        end

        paid = quant*System.getStandardPrice(consq.Symbol,period);
        owner = this.ID;
        item = consq.Symbol;
        bprice = System.getStandardPrice(consq.Symbol,period);
        #The controller must pay the producer for the products
        #println("Producer $producer Paying $paid to $owner for $quant items of $item base $bprice")
        this.Numeraire += paid;
        this.numeraireToBeTaxed += paid; #in numeraireToBeTaxed will be the residual between paid and received numeraire amounts
        Producers.vec[producer].Numeraire -= paid;
        Producers.vec[producer].numeraireToBeTaxed -= paid;
      end

    end
    ######################################################
    ######################################################
    return this
  end
end
###################################################################################
###################################################################################

############### INITP FUNCTION ################
###############################################
function InitP(ListP::List{Producer}, ListV::List{List{Rule}}, _Numeraire::Float64, K::Int64, N::Int64,SystemData,systemConfigFileName)
  try
      PRODUCERS = SystemData["Producers"];
      initializedProducers = 0;
      for tuple in PRODUCERS
          initializedProducers = initializedProducers+1
      end
      if(initializedProducers!=N)
        println("Producers initialization error at ",systemConfigFileName,". Number of producers is mismatching ... exiting");
        quit()
      end
      println("↓ Parsing Producers Data ...")

      prod_id = 0;
      prod_numeraire = 0;
      prod_sector_internal = true;
      init_id = 1;
      for tuple in PRODUCERS
        #Get producer ID
        try
          prod_id = tuple["Id"]
          if(prod_id>N)
            println("Error in ",systemConfigFileName," in producer ",init_id," ID (>N) ... exiting");
            quit()
          end
        catch error
          if isa(error, KeyError)
            println("No ID at ",systemConfigFileName," in producer ",init_id,"... exiting");
            quit()
          end
        end
        #Get producer Numeraire
        try
          prod_numeraire = tuple["Numeraire"];
        catch error
          if isa(error, KeyError)
            println("No Numeraire at ",systemConfigFileName," in producer ",init_id,"... exiting");
            quit()
          end
        end
        #Get producer sector operation
        try
          temp = tuple["Sector"];
          if(temp=="external" || temp=="External")
            prod_sector_internal = false
          else
            prod_sector_internal = true
          end
        catch error
          if isa(error, KeyError)
            println("No Sector at ",systemConfigFileName," in producer ",init_id,"... exiting");
            quit()
          end
        end
        #Check if there is any producer with the same ID
        for producer = 1:length(ListP.vec)
          if(prod_id==ListP.vec[producer].ID)
            println("Conflicting producer ID's at ",systemConfigFileName," ... exiting");
            quit()
          end
        end
        ListP.addContent(Producer(prod_numeraire,prod_sector_internal,prod_id))

        item_symbol = "";
        item_amount = 0;
        #Read producer's Input_Store
        try
          INPUTSTORE = tuple["Input_Store"];
          for item in INPUTSTORE
            try
              item_symbol = item["Symbol"];
            catch error
              if isa(error, KeyError)
                println("No Symbol at ",systemConfigFileName," in producer ",init_id," Input_Store... exiting");
                quit()
              end
            end
            try
              item_amount = item["Amount"];
            catch error
              if isa(error, KeyError)
                println("No Amount at ",systemConfigFileName," in producer ",init_id," Input_Store... exiting");
                quit()
              end
            end
            ListP.vec[prod_id].InputStore.addContent(Symbol(item["Symbol"], item["Amount"],0))
          end
        catch error
          if isa(error, KeyError)
            println("No Input_Store at ",systemConfigFileName," in producer ",init_id," ... exiting")
            quit()
          end
        end
        #Read producer's Output_Store
        try
          OUTPUTSTORE = tuple["Output_Store"];
          for item in OUTPUTSTORE
            try
              item_symbol = item["Symbol"];
            catch error
              if isa(error, KeyError)
                println("No Symbol at ",systemConfigFileName," in producer ",init_id," Output_Store... exiting");
                quit()
              end
            end
            try
              item_amount = item["Amount"];
            catch error
              if isa(error, KeyError)
                println("No Amount at ",systemConfigFileName," in producer ",init_id," Output_Store... exiting");
                quit()
              end
            end
            ListP.vec[prod_id].OutputStore.addContent(Symbol(item["Symbol"], item["Amount"],0))
          end
        catch error
          if isa(error, KeyError)
            println("No Output_Store at ",systemConfigFileName," in producer ",init_id," ... exiting")
            quit()
          end
        end

        #Read producer's Rules
        _rulelist = List{Rule}(Rule)
        _precedent = List{Symbol}(Symbol);
        _ynomlist = List{Int64}(Int64);
        _succedent = Symbol("",0,0)
        try
          RULES = tuple["Rules"]
          for rule in RULES
            inval = 0;
            inamval = 0;
            try
              in = rule["InString"]
              inam = rule["InAmounts"]
              inval = split(in,",")
              inamval = split(inam,",")
              if(length(inval) != length(inamval))
                println("Error in Rule input values in ",systemConfigFileName," in producer ",init_id," ... exiting");
                quit()
              end
            catch error
              if isa(error, KeyError)
                println("Error at InString/InAmounts definition in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                quit()
              end
            end

            for i=1:length(inval)
              _precedent.addContent(Symbol(inval[i],parse(Int,inamval[i]),0))
            end

            try
              for count=1:K
                _ynomlist.addContent(rule["Nom"]);
              end
            catch error
              if isa(error, KeyError)
                println("Error at Nom definition in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                quit()
              end
            end

            initialNominalValue = rule["Nom"];
            try
              PERTURBATIONS = rule["Perturbations"]
              for perturbation in PERTURBATIONS
                try
                  start_period = perturbation["StartPeriod"]
                  end_period = perturbation["EndPeriod"]
                  percentage = perturbation["Percentage"]

                  if((start_period>=1&&start_period<=N)&&(end_period>=1&&end_period<=N)&&(start_period<=end_period))
                    for period=start_period:end_period
                        _ynomlist.vec[period] = convert(Int64,initialNominalValue*percentage)
                    end
                  else
                    println("Error at Perturbation's periods definition in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                    quit()
                  end
                catch error
                  if isa(error, KeyError)
                    println("Error at Perturbation definition in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                    quit()
                  end
                end
              end
            catch error
              if isa(error, KeyError)
                println("Error at Perturbations in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                quit()
              end
            end
            #Compute nominal values given perturbations

            try
              _succedent = Symbol(rule["OutString"],rule["OutAmounts"],0)
            catch error
              if isa(error, KeyError)
                println("Error at OutString/OutAmounts definition in ",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                quit()
              end
            end

            try
              _rulelist.addContent(Rule(_precedent, _succedent, rule["Multiplier"], rule["Type"], rule["Min"], rule["Nom"], rule["Max"],_ynomlist))
            catch error
              if isa(error, KeyError)
                println("Error at Multiplier/Type/Min/Nom/Max definition in",systemConfigFileName," in producer ",init_id," Rules ... exiting");
                quit()
              end
            end
            _precedent.deleteList();
            _ynomlist.deleteList();
            _precedent = List{Symbol}(Symbol);
            _ynomlist = List{Int64}(Int64);
          end

          ListV.addContent(_rulelist);
          _rulelist = List{Rule}(Rule)
        catch error
          if isa(error, KeyError)
            println("No Rules at ",systemConfigFileName," in producer ",init_id," ... exiting")
            quit()
          end
        end

        init_id = init_id+1
      end
  catch error
    if isa(error, KeyError)
      println("No Producers or Error at ",systemConfigFileName," ... exiting");
      quit()
    end
  end
  println("▬ Producers Successfuly Initialized\n")

  println("▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")

  return N
end
###############################################
###############################################


############# CHECKSYS FUNCTION ###############
###############################################
function CheckSys(C::Controller,P::List{Producer}, R::List{List{Rule}},period,f,toConsole,S)
  if(toConsole) println("↑ Displaying Current SYSTEM information ...") end
  # Print Controller Information
  #=println("→ Controller Info:")
  for i=1:C.Goals.getSize()
    Simb = C.getGoal(i)
    println("    ♦\"",Simb.Symbol,"\": ",Simb.Amount," units @ ",C.getPrice(i))
  end=#

  if(toConsole) println("\n→ Producers Info:") end
  for i=1:P.getSize()
    if(P.vec[i].Enabled)
        if(toConsole) println("► Producer $i Info [",P.vec[i].ID,"]:"); end
        if(toConsole)
          if (P.vec[i].Internal==true)
            println("► From Internal Sector.")
          else
            println("► From External Sector.")
          end
        end
        if(toConsole) println("    ♦Numeraire: ",P.vec[i].Numeraire) end  #Imprime o numerário do produtor P.vec[i]
        if(period==1) @printf(f,"numeraires_0(%d)=%d\n",i,P.vec[i].Numeraire); end  #Output to file numerário do produtor P.vec[i]
        if(toConsole) println("    ♦InputStore [",length(P.vec[i].InputStore.vec),"]:"); end
      for j=1:length(P.vec[i].InputStore.vec)
        Simb = P.vec[i].InputStore.vec[j];
          if(toConsole) println("      ♦\"",Simb.Symbol,"\": ",Simb.Amount," units") end #Imprime as quantidades(Simb.Amount) do produto
        # Simb.Symbol do produtor P.vec[i], que estão na InputStore
        @printf(f,"inputStore_%s(%d,%d)=%d\n",Simb.Symbol,i,period,Simb.Amount); #Sintaxe do Scilab

      end

        if(toConsole) println("    ♦OutputStore [",length(P.vec[i].OutputStore.vec),"]:"); end
      for k=1:length(P.vec[i].OutputStore.vec)
        Simb = P.vec[i].OutputStore.vec[k];
          if(toConsole) println("      ♦\"",Simb.Symbol,"\": ",Simb.Amount," units") end#Imprime as quantidades(Simb.Amount) do produto
        # Simb.Symbol do produtor P.vec[i], que estão na OutputStore
        @printf(f,"outputStore_%s(%d,%d)=%d\n",Simb.Symbol,i,period,Simb.Amount); #Sintaxe do Scilab
      end
    end
  end

  #Prices output
  if(toConsole) println("► Prices for period $period"); end
  if(period==1) per = 1; else per = period-1 end
  for item=1:length(S.PricingList.vec)
    if(toConsole) println("    ♦",S.PricingList.vec[item].Symbol,"-",S.PricingList.vec[item].PriceList.vec[per]); end
    @printf(f,"price(%d,%d)=%.10f\n",item,period,S.PricingList.vec[item].PriceList.vec[per]); #Sintaxe do Scilab
  end
  if(toConsole) println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n") end
end

function CheckRules(R::List{List{Rule}})
  println("↑ Displaying Current Rules")
  # Print Rules
  for prod=1:length(R.vec)
    println("► Rules for Producer$prod")
    for rule=1:length(R.vec[prod].vec)
      println("  ♦ Rule $rule")
      print("    Antecedent: ")
      for ant = 1:length(R.vec[prod].vec[rule].Antecedent.vec)
        print(R.vec[prod].vec[rule].Antecedent.vec[ant]," ")
      end
      println("\n    Consequent: ",R.vec[prod].vec[rule].Consequent)
      println("    Ymin: ",R.vec[prod].vec[rule].Ymin)
      println("    Initial Ynom: ",R.vec[prod].vec[rule].YnomList.vec[1])
      println("    Ymax: ",R.vec[prod].vec[rule].Ymax)
    end
  end
  println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")
end
###############################################
###############################################

###################################################################################
###################################################################################


###################################################################################
###################################################################################
#BANK AGENT

################## BANK TYPE ##################
###############################################
type Bank
  ID::Int64
  Assets::Float64  #Assets as numeraire
  Liabilities::Float64  #Liabilities as numeraire
  Credits::List{CreditContract} #List of credits done by the bank

  function Bank(id,credits::List{CreditContract}, assets = 0.0, liabilities = 0.0)
    this = new();
    id = ID;
    Assets = assets;
    Liabilities = liabilities;
    Credits = credits;
    return this
  end
end
###############################################
###############################################
