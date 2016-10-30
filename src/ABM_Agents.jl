include("ABM_Transactions.jl") #includes Symbol,Rule and Generic List types
using JSON

#AGENTS OF MODEL
###################################################################################
###################################################################################
#CONTROLLER AGENT
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
###################################################################################
###################################################################################
#INIT CONTROLLER AGENT METHOD
function InitC(C::Controller,Taxes,SystemData,systemConfigFileName)
  C.taxPercentage = Taxes;
  # looks for controller goals in JSON format in Agents.json file
  println("↓ Parsing Controller Data ...")
  try
    ControllerData = SystemData["ControllerGoals"]
  catch error
    if isa(error, KeyError)
      println("No ControllerGoals at ",systemConfigFileName," ... exiting")
      quit()
    end
  end

  controllerParameters = SystemData["ControllerParameters"];
  for tuple in controllerParameters
    C.taxPercentage = tuple["taxingPercentage"];
  end

  if(C.taxPercentage<0.0) C.taxPercentage = 0.0
  end

  if(C.taxPercentage>1.0) C.taxPercentage = 1.0
  end

  ControllerData = SystemData["ControllerGoals"]
  for tuple in ControllerData
    C.Goals.addContent(ControllerGoal(tuple["simbol"], tuple["Ymin"],tuple["Ynom"]))
    C.Prices.addContent(tuple["price"])
  end

  println("▬ Controller Successfuly Initialized\n")
end

###################################################################################
###################################################################################
#PRODUCER AGENT
type Producer
  Numeraire::Float64
  InputStore::List{Symbol}
  OutputStore::List{Symbol}
  Enabled::Bool
  ID::Int64
  numeraireToBeTaxed::Float64
  Internal::Bool
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

  function Producer(Numeraire = 0.0,internal=true, id_ = 0)
    this = new()
    this.Numeraire = Numeraire
    this.InputStore = List{Symbol}(Symbol)
    this.OutputStore = List{Symbol}(Symbol)
    this.Enabled = true
    this.ID = id_
    this.Internal = internal

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
    this.deleteOutputStore = function(item,quant)
      this.OutputStore.vec[item].Amount -= quant
      if(this.OutputStore.vec[item].Amount == 0)
        this.OutputStore.deleteContent(item)
      end
    end
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
    return this
  end
end
###################################################################################
###################################################################################

function InitP(ListP::List{Producer}, ListV::List{List{Rule}}, _Numeraire::Float64, K::Int64,SystemData,systemConfigFileName)
  #detect how many producers are described in rules part of System.json
  producerExists = true;
  producerID_ = 1;
  N = 0;
  while producerExists
    try
        producer = SystemData["Producer$producerID_"];
    catch error
      if isa(error, KeyError)
        producerExists = false;
        break;
      end
    end
    N +=1;
    producerID_+=1;
  end
  #init Producers
  # looks for controller goals in JSON format in Agents.json file
  println("↓ Parsing Producers Data ...")

  try
    Numeraires = SystemData["Numeraire"]
  catch error
    if isa(error, KeyError)
      println("No Numeraire at ",systemConfigFileName," ... exiting")
      quit()
    end
  end

  try
    Classifications = SystemData["SectorClassification"]
  catch error
    if isa(error, KeyError)
      println("No SectorClassification at ",systemConfigFileName," ... exiting")
      quit()
    end
  end

  Classifications = SystemData["SectorClassification"]
  Numeraires = SystemData["Numeraire"]
  Num_Assigned = false
  internal_sector = true

  Current_Numeraire = 0;
  Current_ID = 0;
  Current_Sec_Internal = internal_sector

  for i = 1:N
    for tuple in Numeraires
      if(tuple["producer"]<=N && tuple["producer"]==i)
        Current_Numeraire = tuple["value"]
        Current_ID = i
        Num_Assigned = true
      end
    end

    for tuple in Classifications
      if(Num_Assigned && tuple["producer"]==Current_ID)
        if (tuple["type"]=="internal")
          Current_Sec_Internal = true
        elseif (tuple["type"]=="external")
          Current_Sec_Internal = false
        else
          Current_Sec_Internal = true
        end
      end
    end

    if(!Num_Assigned)
        ListP.addContent(Producer(_Numeraire))
        println("  † No Numeraire Initialization for Producer$i")
    else
        ListP.addContent(Producer(Current_Numeraire,Current_Sec_Internal,Current_ID))   #id; Numeraire; State;
        Num_Assigned = false
    end
  end

  # First we will read the inputStore initialization for each producer
  try
    InputStoreData = SystemData["InputStore"]
  catch error
    if isa(error, KeyError)
      println("No InputStore at ",systemConfigFileName," ... exiting")
      quit()
    end
  end

  InputStoreData = SystemData["InputStore"]
  for tuple in InputStoreData
    if(tuple["producer"]<=N)
      ListP.vec[tuple["producer"]].InputStore.addContent(Symbol(tuple["simbol"], tuple["amount"],0))
    end
  end

  # Then we will read the OutputStore initialization for each producer
  try
    InputStoreData = SystemData["OutputStore"]
  catch error
    if isa(error, KeyError)
      println("No OutputStore at ",systemConfigFileName," ... exiting")
      quit()
    end
  end

  OutputStoreData = SystemData["OutputStore"]
  for tuple in OutputStoreData
    if(tuple["producer"]<=N)
      ListP.vec[tuple["producer"]].OutputStore.addContent(Symbol(tuple["simbol"], tuple["amount"],0))
    end
  end

  println("▬ Producers Successfuly Initialized\n")

  # In last we will initialize all the rules
  println("↓ Parsing Rules Data ...")
  _rulelist = List{Rule}(Rule)

  _precedent = List{Symbol}(Symbol);
  _ynomlist = List{Int64}(Int64);
  _succedent = Symbol("",0,0)

  existingRule::Bool = true
  for nProducers=1:N
    producer = "Producer$nProducers"
    try
    ProducerRules = SystemData[producer]
    catch error
      if isa(error, KeyError)
        existingRule = false
      end
    end

    if existingRule==true # if there are rules for the current producer, read them
      ProducerRules = SystemData[producer]
      for tuple in ProducerRules
        in = tuple["instring"]
        inam = tuple["inamounts"]

        inval = split(in,",")
        inamval = split(inam,",")

        if(length(inval) != length(inamval))
          println("Error in Rules Definition in ",systemConfigFileName," ... exiting");
          quit()
        end

        for i=1:length(inval)
          _precedent.addContent(Symbol(inval[i],parse(Int,inamval[i]),0))
        end
        for count=1:K
          _ynomlist.addContent(tuple["nom"]);
        end
        _succedent = Symbol(tuple["outstring"],tuple["outamounts"],0)

        _rulelist.addContent(Rule(_precedent, _succedent, tuple["multi"], tuple["type"], tuple["min"], tuple["nom"],tuple["max"],_ynomlist))
        _precedent.deleteList();
        _ynomlist.deleteList();
        _precedent = List{Symbol}(Symbol);
        _ynomlist = List{Int64}(Int64);
      end
    else
      println("  † No Rule Specifiaction for $producer\n")
    end

    ListV.addContent(_rulelist);
    _rulelist = List{Rule}(Rule)
    existingRule = true
  end
  println("▬ Producer Rules Successfuly Initialized\n")

   println("↓ Parsing Impulse Perturbations Data ...")

  impulses = SystemData["ImpulsePerturbations"];
  for tuple in impulses
    producer = tuple["producer"]; ruleID = tuple["rule"]; percent = tuple["percentage"];
    startPeriod = tuple["startperiod"]; endPeriod = tuple["endperiod"];
    if(producer>=1 && producer<=N)
      if(ruleID>=1 && ruleID<=length(ListV.vec[producer].vec))
        if((startPeriod>=1&&startPeriod<=K)&&(endPeriod>=1&&endPeriod<=K))
          for period=startPeriod:endPeriod
             ListV.vec[producer].vec[ruleID].YnomList.vec[period] =  ListV.vec[producer].vec[ruleID].YnomList.vec[period]*percent;
          end
        else
          println(" ► Wrong period value in impulse perturbations");
        end
      else
        println(" ► Wrong rule value in impulse perturbations");
      end
    else
      println(" ► Wrong producer value in impulse perturbations");
    end
  end

  println("▬ Impulse Perturbations Successfuly Initialized\n")
  println("▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")

  return N
end

###################################################################################
###################################################################################
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
  if(toConsole) println("Prices for period $period"); end
  if(period==1) per = 1; else per = period-1 end
  for item=1:length(S.PricingList.vec)
    if(toConsole) println(S.PricingList.vec[item].Symbol,"-",S.PricingList.vec[item].PriceList.vec[per]); end
    @printf(f,"price(%d,%d)=%.10f\n",item,period,S.PricingList.vec[item].PriceList.vec[per]); #Sintaxe do Scilab
  end
  if(toConsole) println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n") end
end

function CheckRules(R::List{List{Rule}})
  println("↑ Displaying Current Rules")
  # Print Rules
  for prod=1:length(R.vec)
    println("    ♦Rules for Producer$prod")
    for rule=1:length(R.vec[prod].vec)
      println("Antecedent: ")
      for ant = 1:length(R.vec[prod].vec[rule].Antecedent.vec)
        print(R.vec[prod].vec[rule].Antecedent.vec[ant])
      end
      println("Consequent: ",R.vec[prod].vec[rule].Consequent)
      println("Ymin: ",R.vec[prod].vec[rule].Ymin)
      println("Ynom: ",R.vec[prod].vec[rule].Ynom)
      println("Ymax: ",R.vec[prod].vec[rule].Ymax)
    end
  end
  println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")
end
###################################################################################
###################################################################################
