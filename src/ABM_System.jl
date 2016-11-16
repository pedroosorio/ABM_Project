include("ABM_Agents.jl")

###################################################################################
###################################################################################
type SuperSystem
  C::Controller           #Controller Object
  P::List{Producer}       #List of Producers
  V::List{List{Rule}}     #List of Rules per Producer
  B::List{BList_Cell}     #B List
  K::Int64                #K cycles
  N::Int64                #N Producing Systems
  F::List{Bank}           #List of Financial institutions (Banks)
  PricingList::List{StandardPriceCell}   #List of prices by Symbol
  ActiveProducers::Int64  # Current number of active producers in the super system

  OutputProducersParameters::Function #Prints important producer configuration
  DeleteProducer::Function #Deletes a producer
  NecessaryRulesConsumption::Function #All producers perform their necessary rules

  SaleableRulestoOutputStore::Function #All producers produce at their maximum capacity
  #until ynom and take to their input store what they need for the next K Cycle
  ProductionAnnouncement::Function ##All producers announce their maximum production capacity
  #until ynom and take to their input store what they need for the next K Cycle
  addOffer::Function #Adds an offer to the BList
  clearOffers::Function #Clears the BList

  BuyingOffers::Function #Enables the ordering mechanism
  BuyFromOrders::Function #Buys items based on the ordering mechanism
  BuyItems::Function #Producers buy what they want/need from other producers
  BuyItemsfromOutputStore::Function #All producers run through the other producers outputstores
  #to buy what they need

  ControllerAction::Function #Controller buys what we needs and apply taxes
  getStandardPrice::Function #Returns the standard price for each symbol
  ApplyTaxes::Function #Controller applies taxes to every producer if applicable
  ProcessCredit::Function #Function that processes credit contract over periods
  CheckSys::Function #Prints system information
  #File output functions
  PrintSteadyState::Function #Prints the steady state of each agent on the simulation file
  function SuperSystem(systemConfigFileName)
    this = new()
    cd(dirname(Base.source_path())); #Change current working directory
    completePathCfgFile = string("./",systemConfigFileName);
    Configuration = JSON.parsefile(completePathCfgFile) #Parse System.json to get system info
    println("↓ Parsing System JSON Config File ...")

    this.F = List{Bank}(Bank)         #List of Financial institutions (Banks)
    try
      SYSTEM_DATA = Configuration["System"] #Get System Block
      try
        SIM_PROPERTIES = SYSTEM_DATA["SimulationProperties"] #Get sim properties
        for tuple in SIM_PROPERTIES
          this.K = tuple["K"]
          this.N = tuple["N"]
        end
        try
          PRICES = SYSTEM_DATA["Pricing"]
          this.PricingList = List{StandardPriceCell}(StandardPriceCell)
          this.PricingList.deleteList();
          for tuple in PRICES
            _priceList = List{Float64}(Float64);
            for count=1:this.K
              _priceList.addContent(tuple["Price"]);
            end
            symb = tuple["Symbol"]
            this.PricingList.addContent(StandardPriceCell(symb,_priceList));
            _priceList.deleteList();
          end
        catch error
          if isa(error, KeyError)
            println("No Pricing data or Errors in ",systemConfigFileName," ... exiting")
            quit()
          end
        end
      catch error
        if isa(error, KeyError)
          println("No SimulationProperties or Errors data in ",systemConfigFileName," ... exiting")
          quit()
        end
      end

      #Initialize Banks
      try
        BANKS = SYSTEM_DATA["Banks"] #Get sim properties
        bank_id = 0;
        bank_ass = 0.0;
        bank_liab = 0.0;
        for item in BANKS
          try
            bank_id = item["ID"];
            bank_ass = item["Assets"];
            bank_liab = item["Liabilities"];

            for b=1:length(this.F.vec)
              if(this.F.vec[b].ID == bank_id)
                println("Error in Bank definition at ",systemConfigFileName,". Banks with same ID's ... exiting")
                quit()
              end
            end
            this.F.addContent(Bank(bank_id,bank_ass,bank_liab));
          catch error
            if isa(error, KeyError)
              println("Error in Bank definition at ",systemConfigFileName," ... exiting")
              quit()
            end
          end
        end

        println("▬ Financial Institutes Initialized\n")
      catch error
        if isa(error, KeyError)
          println("No Banks at System data in ",systemConfigFileName," ... exiting")
          quit()
        end
      end
    catch error
      if isa(error, KeyError)
        println("No System data in ",systemConfigFileName," ... exiting")
        quit()
      end
    end

    println("▬ System Parameters Successfuly Initialized\n")
    println("→ Simulation Parameters: ",this.K," Periods & ",this.N," Producers\n");
    println("▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")
    #define Objects and read JSON configuration Files
    this.C = Controller();                    #Controller Object
    this.P = List{Producer}(Producer)         #List of Producers
    this.V = List{List{Rule}}(List{Rule})     #List of Rules per Producer
    this.B = List{BList_Cell}(BList_Cell)     #BList - with sales
    InitC(this.C,1.0,Configuration,systemConfigFileName) #Initialize the Controller
    this.N = InitP(this.P,this.V,this.F,0.0,this.K,this.N,Configuration,systemConfigFileName) #Initialize the Producers
    this.ActiveProducers = this.N;
    InitB(this.B,this.V) #Initialize the B* List
    println("▬ System Initialized\n")
    #SYSTEM FUNCTIONS
   ###################################################################################
   ###################################################################################
    this.OutputProducersParameters = function(f)
    end
   ###################################################################################
   ###################################################################################
    this.NecessaryRulesConsumption = function(f,period)
      producersDeleted = 0;
      for prod = 1:length(this.V.vec) # Run through every rule of every producer
        if(this.P.vec[prod].Enabled)
          this.P.vec[prod].numeraireToBeTaxed = 0.0;
          success = true
        for rule = 1:length(this.V.vec[prod].vec)
          if(this.V.vec[prod].vec[rule].Type == "d") #If it is necessary, execute it
            #if the necessary rule is not possible, then the producer will be deleted
            pre = this.V.vec[prod].vec[rule].Antecedent
            done,amounts = this.P.vec[prod].existsInInputStore(pre)
            #this amounts variable will say how many items of each precedent symbol is available
            if(!done)
              success = false;
              #println("► Necessary Rule Failed from ", this.P.vec[prod].ID)
              break
            else
              #get the minimum amount available
              if(length(amounts.vec)==0)
                available = this.V.vec[prod].vec[rule].YnomList.vec[period]
              else
                available = 10000000000
                for am=1:length(amounts.vec)
                    if(amounts.vec[am]<available)
                      available = amounts.vec[am]
                    end
                end
                if(available > this.V.vec[prod].vec[rule].YnomList.vec[period])
                    available = this.V.vec[prod].vec[rule].YnomList.vec[period];
                end
              end
              this.P.vec[prod].deletePrecedentInputStore(pre,available)

              if(this.V.vec[prod].vec[rule].Consequent.Symbol == "''")
              else
                consq = this.V.vec[prod].vec[rule].Consequent
                this.P.vec[prod].addConsequentInputStore(consq,available)
              end

              #Flag consumption in output file
              for preitem = 1:length(pre.vec)
                #@printf(f,"@REPORT:%d:CONSUMPTION:%s:%d%s",this.P.vec[prod].ID,pre.vec[preitem].Symbol,available,"\n");
                end
            end
          end
        end
        if(success==false)
          #Delete the producer
          this.DeleteProducer(prod)
          @printf(f,"live(%d,%d)=0%s",this.P.vec[prod].ID,period,"\n");
          #println("Producer",this.P.vec[prod].ID," Deleted")
          this.ActiveProducers -= 1
        else
          @printf(f,"live(%d,%d)=1%s",this.P.vec[prod].ID,period,"\n");
          #println("Producer",this.P.vec[prod].ID," Successful")
          success = false
        end
        end
      end

      if(this.ActiveProducers==0)
        @printf(f,"@SUPERSYSTEM_DEAD%s","\n");
        @printf(f,"@SIMULATION_END%s","\n");
        println(" ↓ All producers deleted ... Deleting SuperSystem")
        quit()
      end
    end
   ###################################################################################
   ###################################################################################
    this.DeleteProducer = function(Prod::Int64)
      this.P.vec[Prod].Enabled = false #We should test this flag whenever we wish to use
      # a producer information.
    end
  ###################################################################################
  ###################################################################################
    this.SaleableRulestoOutputStore = function()#NOT TO USE
      for prod = 1:length(this.V.vec) # Run through every rule of every producer
        if(this.P.vec[prod].Enabled)
          for rule = 1:length(this.V.vec[prod].vec)
            if(this.V.vec[prod].vec[rule].Type == "a") #If it is saleable, execute it
              pre = this.V.vec[prod].vec[rule].Antecedent
              done,amounts = this.P.vec[prod].existsInInputStore(pre)
              if(!done)
                success = false;
                #println("► Saleable Rule Failed from ",this.P.vec[prod].ID)
                #println("Producer",this.P.vec[prod].ID," Failed to Produce")
                break
              else
                #get the minimum amount available
                if(length(amounts.vec)==0)
                  available = this.V.vec[prod].vec[rule].Ynom
                else
                  available = 10000000000
                  for am=1:length(amounts.vec)
                      if(amounts.vec[am]<available)
                        available = amounts.vec[am]
                      end
                  end
                  if(available > this.V.vec[prod].vec[rule].Ynom)
                      available = this.V.vec[prod].vec[rule].Ynom
                  end
                end
                this.P.vec[prod].deletePrecedentInputStore(pre,available)
                consq = this.V.vec[prod].vec[rule].Consequent
                #If this producer will consume what he produced, move the necessary amount to its input store
                for rules=1:length(this.V.vec[prod].vec)
                  precedents = this.V.vec[prod].vec[rules].Antecedent
                  for symbols=1:length(precedents.vec)
                    if(consq.Symbol==precedents.vec[symbols].Symbol)#If we need this for some rule
                      this.P.vec[prod].transferToInputStore(consq.Symbol,precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].Ynom)
                      available -= precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].Ynom
                      #println("◄ Kept ",precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].Ynom , " items of ",consq.Symbol," to Next Cycle")
                    end
                  end
                end
                this.P.vec[prod].addConsequentOutputStore(consq,available)
                #println("► Added ",available, " items of ", consq.Symbol," to sell")
                #println("Producer",this.P.vec[prod].ID," Successful in Production")
              end
            end
          end
        end
      end

    end
  ###################################################################################
  ###################################################################################
    this.ProductionAnnouncement = function(f,period)
      for prod = 1:length(this.V.vec) # Run through every rule of every producer
        if(this.P.vec[prod].Enabled)
          for rule = 1:length(this.V.vec[prod].vec)
            if(this.V.vec[prod].vec[rule].Type == "a") #If it is saleable, execute it
              pre = this.V.vec[prod].vec[rule].Antecedent
              done,amounts = this.P.vec[prod].existsInInputStore(pre)
              if(!done)
                success = false;
                println("► Saleable Rule Failed from ",this.P.vec[prod].ID)
                println("Producer",this.P.vec[prod].ID," Failed to Produce in period ",period)
                break
              else
                #get the minimum amount available
                if(length(amounts.vec)==0)
                  available = this.V.vec[prod].vec[rule].YnomList.vec[period]
                else
                  available = 10000000000
                  for am=1:length(amounts.vec)
                      if(amounts.vec[am]<available)
                        available = amounts.vec[am]
                      end
                  end
                  if(available > this.V.vec[prod].vec[rule].YnomList.vec[period])
                      available = this.V.vec[prod].vec[rule].YnomList.vec[period]
                  end
                end
                consq = this.V.vec[prod].vec[rule].Consequent
                #If this producer will consume what he produced, move the necessary amount to its input store
                for rules=1:length(this.V.vec[prod].vec)
                  precedents = this.V.vec[prod].vec[rules].Antecedent
                  for symbols=1:length(precedents.vec)
                    if(consq.Symbol==precedents.vec[symbols].Symbol)#If we need this for some rule
                      this.P.vec[prod].keepItems(pre,consq,precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].YnomList.vec[period])
                      this.V.vec[prod].vec[rules].antecedentsReady = true;
                      available -= precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].YnomList.vec[period]
                      #println("◄ Kept ",precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].Ynom , " items of ",consq.Symbol," to Next Cycle")
                      #@printf(f,"@REPORT:%d:KEPT:%s:%d%s",this.P.vec[prod].ID,consq.Symbol,precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].YnomList.vec[period],"\n");
                    end
                  end
                end
                #Now, instead of producing and adding the items to the output store, we will announce our production levels
                #in the BList
                #Consult Standard price in Systems price table
                this.addOffer(consq.Symbol,available,this.getStandardPrice(consq.Symbol,period),this.P.vec[prod].ID)
                @printf(f,"offers(%d,%d)=%d%s",this.P.vec[prod].ID,period,available,"\n");
                #println("Announced ",available, " items of ", consq.Symbol)
                this.P.vec[prod].setToProduction(this.V,consq.Symbol,available)#Set the inputstore item for production
                #println("Producer",this.P.vec[prod].ID," Successful in Announcement\n")
              end
            end
          end
        end
      end

    end
  ###################################################################################
  ###################################################################################
    this.getStandardPrice = function(symbol,period)
      for product=1:length(this.PricingList.vec)
        if(symbol == this.PricingList.vec[product].Symbol)
          return this.PricingList.vec[product].PriceList.vec[period]
        end
      end
      return 0;
    end
  ###################################################################################
  ###################################################################################
    this.BuyFromOrders = function(f,period)
      #This function triggers the buy-sale procedure, but based on placed orders by the producers
      #########################
      # Identify orders for each producer
      for prod = 1:length(this.P.vec)
        if(this.P.vec[prod].Enabled)
          for rule = 1:length(this.V.vec[prod].vec)
            precedents = this.V.vec[prod].vec[rule].Antecedent #Every producer should try to be buy his nominal needs
            newYnom = this.V.vec[prod].vec[rule].Ynom
            stdYnom = this.V.vec[prod].vec[rule].Ynom
            consquent = this.V.vec[prod].vec[rule].Consequent.Symbol
            for shelf=1:length(this.B.vec) #If we have an order for that item, update newYnom for the rule
              for offers=1:length(this.B.vec[shelf].Offers.vec)
                if(this.B.vec[shelf].Offers.vec[offers].Producer == prod && consquent == this.B.vec[shelf].Product)
                  newYnom = this.B.vec[shelf].Offers.vec[offers].OrderedUnits;
                  if(newYnom>stdYnom)
                    newYnom = stdYnom;
                  end
                  for rules=1:length(this.V.vec[prod].vec)
                    if(this.V.vec[prod].vec[rules].antecedentsReady==true)
                      precedents = this.V.vec[prod].vec[rules].Antecedent
                      for symbols=1:length(precedents.vec)
                        if(consquent==precedents.vec[symbols].Symbol)
                          #newYnom+=precedents.vec[symbols].Amount*this.V.vec[prod].vec[rules].Ynom
                        end
                      end
                    end
                  end
                end
              end
            end
            if(this.V.vec[prod].vec[rule].antecedentsReady==false)
              for products=1:length(precedents.vec) #Buy precedents accordingly to order volume
                if(precedents.vec[products].Symbol != "*")
                  buyingFromProducer = 0
                  targetAmount = precedents.vec[products].Amount*newYnom #Get the target amount
                  minAmount = precedents.vec[products].Amount*newYnom # and min amount
                  target = precedents.vec[products].Symbol #for every target
                  boughtTargets = 0;
                  for shelf=1:length(this.B.vec)
                    if(this.B.vec[shelf].Product==target) #this is the shelf we want to analyze
                      for offers=1:length(this.B.vec[shelf].Offers.vec)
                        if(targetAmount-boughtTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                          buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
                        else
                          buyingFromProducer = targetAmount-boughtTargets
                        end
                        println("Prod$prod buying $buyingFromProducer of $target from ",this.B.vec[shelf].Offers.vec[offers].Producer)
                        boughtTargets += buyingFromProducer
                        this.P.vec[this.B.vec[shelf].Offers.vec[offers].Producer].atomicSale(this.V,this.P,precedents.vec[products],buyingFromProducer,this.P.vec[prod].ID,this,period)
                        if(boughtTargets>=targetAmount)
                          break;
                        end
                      end
                    end
                  end
                end
              end
            else
              this.V.vec[prod].vec[rule].antecedentsReady = false;
            end
          end
        end
      end
      println("\n")
      #########################
    end
  ###################################################################################
  ###################################################################################
    this.BuyingOffers = function(f,period)
      #This functions intends to make a polling run through the producers to determine what will they buy
      #to avoid waste. This mechanism relies on the announcement of production of every producer. After that,
      #the producers search on the BList to find out their percentile to minimize the numeraire loss. After
      #determining the percentile, they will make orders, so the producing agents know what to buy, before making
      #a purchase for production.

      for prod = 1:length(this.P.vec)
        if(this.P.vec[prod].Enabled)
          itemsToBuy = List{ControllerGoal}(ControllerGoal); #To gather items to buy
          #First determine the percentil of every rule, then sum up the matching type items, then buy
          for rule = 1:length(this.V.vec[prod].vec)
            percentil = 1.0;
            tempPercentil = 1.0;
            precedents = this.V.vec[prod].vec[rule].Antecedent #Every producer should try to be buy his nominal needs
            for products=1:length(precedents.vec) #Run through the precedents of every rule to get the percentil
              if(precedents.vec[products].Symbol!="*")
                availableTargets = 0
                buyingFromProducer = 0
                targetAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ynom #Get the target amount
                minAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ymin # and min amount
                target = precedents.vec[products].Symbol #for every target
                #Run through the BList to find available items
                for shelf=1:length(this.B.vec)
                  if(this.B.vec[shelf].Product==target) #this is the shelf we want to analyze
                    for offers=1:length(this.B.vec[shelf].Offers.vec)
                      if(targetAmount-availableTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                        buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
                      else
                        buyingFromProducer = targetAmount-availableTargets
                      end
                      availableTargets += buyingFromProducer
                    end
                    #After running through all the offers, update the percentile
                    tempPercentil = availableTargets/targetAmount
                    if(tempPercentil<percentil)
                      percentil = tempPercentil
                    end
                  end
                end
              end
            end

            #Here we already determined the percentil of the rule
            #Run through the precedents of every rule to get the percentil
            for products=1:length(precedents.vec)
              foundItem = false;
              if(precedents.vec[products].Symbol!="*")
                targetAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ynom*percentil
                minAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ymin
                target = precedents.vec[products].Symbol
                for item=1:length(itemsToBuy.vec) #Add the items by thye percentil to buy next
                  if(itemsToBuy.vec[item].Symbol == target)
                    itemsToBuy.vec[item].Ynom +=  targetAmount
                    itemsToBuy.vec[item].Ymin +=  minAmount
                    foundItem = true
                  end
                end
                if(foundItem == false)
                  itemsToBuy.addContent(ControllerGoal(target,minAmount,targetAmount))
                end
              end
            end
          end
          #########################
          #Now that we have what to buy, based of announcements, lets buy
          for item=1:length(itemsToBuy.vec)
            target = itemsToBuy.vec[item].Symbol;
            targetAmount = itemsToBuy.vec[item].Ynom;
            minAmount = itemsToBuy.vec[item].Ymin;
            if(this.P.vec[prod].existsInInputStoreItem(target,targetAmount)==false) #if we already have the item, ignore
            #it already takes into account the items set to further production
              alreadyInStore = this.P.vec[prod].getSymbolAmount(target);
              targetAmount -= alreadyInStore #remove what he already has instore from previous periods
              targetComplete = false
              boughtTargets = 0
              buyingFromProducer = 0
              #println("Producer $prod buying $targetAmount items of $target")
              for shelf=1:length(this.B.vec)
                if(this.B.vec[shelf].Product==target) #Search through the shelfs for the required item
                  for offers=1:length(this.B.vec[shelf].Offers.vec)
                    if(targetAmount-boughtTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                      buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
                    else
                      buyingFromProducer = targetAmount-boughtTargets
                    end
                    boughtTargets += buyingFromProducer
                    this.B.vec[shelf].Offers.vec[offers].OrderedUnits += buyingFromProducer
                    if(boughtTargets==targetAmount)
                      targetComplete = true
                      break
                    end
                  end
                  #After running through all the offers, check if at least the minimum has been accomplished
                  if(boughtTargets>=minAmount)
                    targetComplete = true
                  end
                end
                if(targetComplete)
                  break
                end
              end
            end
          end
        end
      end
      #########################
      #Update controller orders, which are always at the nominal values
      for goal=1:length(this.C.Goals.vec)
        target = this.C.Goals.vec[goal].Symbol
        targetAmount = this.C.Goals.vec[goal].Ynom
        minAmount = this.C.Goals.vec[goal].Ymin
        boughtTargets = 0
        targetComplete = false
        for shelf=1:length(this.B.vec)
          if(this.B.vec[shelf].Product==target) #Search through the shelfs for the required item
            for offers=1:length(this.B.vec[shelf].Offers.vec)
              if(targetAmount-boughtTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
              else
                buyingFromProducer = targetAmount-boughtTargets
              end
              boughtTargets += buyingFromProducer
              this.B.vec[shelf].Offers.vec[offers].OrderedUnits += buyingFromProducer
              if(boughtTargets==targetAmount)
                targetComplete = true
                break
              end
            end
            #After running through all the offers, check if at least the minimum has been accomplished
            if(boughtTargets>=minAmount)
              targetComplete = true
            end
          end
          if(targetComplete)
            break
          end
        end
      end
      #########################

      #########################
      #Update units
      for shelf=1:length(this.B.vec)
        target = this.B.vec[shelf].Product
        #println("Requests for $target:")
        for offers=1:length(this.B.vec[shelf].Offers.vec)
          quantity =  this.B.vec[shelf].Offers.vec[offers].OrderedUnits
          this.B.vec[shelf].Offers.vec[offers].Units = quantity
          #println(" + $quantity")
        end
      end
      #########################
    end
  ###################################################################################
  ###################################################################################
    this.BuyItems = function(f,period)
      target::AbstractString = ""
      for prod = 1:length(this.P.vec)
        if(this.P.vec[prod].Enabled)
          itemsToBuy = List{BuyingGoal}(BuyingGoal); #To gather items to buy
          #First determine the percentil of every rule, then sum up the matching type items, then buy
          for rule = 1:length(this.V.vec[prod].vec)
            percentil = 1.0;
            tempPercentil = 1.0;
            precedents = this.V.vec[prod].vec[rule].Antecedent #Every producer should try to be buy his nominal needs
            for products=1:length(precedents.vec) #Run through the precedents of every rule to get the percentil
              if(precedents.vec[products].Symbol!="*")
                availableTargets = 0
                buyingFromProducer = 0
                targetAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].YnomList.vec[period] #Get the target amount
                minAmount = precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ymin # and min amount
                target = precedents.vec[products].Symbol #for every target

                #Run through the BList to find available items
                for shelf=1:length(this.B.vec)
                  if(this.B.vec[shelf].Product==target) #this is the shelf we want to analyze
                    for offers=1:length(this.B.vec[shelf].Offers.vec)
                      if(targetAmount-availableTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                        buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
                      else
                        buyingFromProducer = targetAmount-availableTargets
                      end
                      availableTargets += buyingFromProducer
                    end
                    #After running through all the offers, update the percentile
                    tempPercentil = availableTargets/targetAmount
                    if(tempPercentil<percentil)
                      percentil = tempPercentil
                    end
                  end
                end
              end
            end
            #Here we already determined the percentil of the rule
            for products=1:length(precedents.vec) #Run through the precedents of every rule to get the percentil
              foundItem = false;
              if(precedents.vec[products].Symbol!="*")
                targetAmount = convert(Int64,precedents.vec[products].Amount*this.V.vec[prod].vec[rule].YnomList.vec[period]*percentil)
                minAmount = convert(Int64,precedents.vec[products].Amount*this.V.vec[prod].vec[rule].Ymin)
                target = precedents.vec[products].Symbol
                for item=1:length(itemsToBuy.vec) #Add the items by thye percentil to buy next
                  if(itemsToBuy.vec[item].Symbol == target)
                    itemsToBuy.vec[item].targetAmount +=  convert(Int64,targetAmount)
                    itemsToBuy.vec[item].minimumAmount +=  convert(Int64,minAmount)
                    foundItem = true
                  end
                end
                if(foundItem == false)
                  itemsToBuy.addContent(BuyingGoal(target,minAmount,targetAmount))
                end
              end
            end
          end
          #########################
          #Now that we have what to buy, in the required levels, lets buy !
          for item=1:length(itemsToBuy.vec)
            target = itemsToBuy.vec[item].Symbol;
            targetAmount = itemsToBuy.vec[item].targetAmount;
            minAmount = itemsToBuy.vec[item].minimumAmount;
            if(this.P.vec[prod].existsInInputStoreItem(target,targetAmount)==false) #if we already have the item, ignore
            #it already takes into account the items set to further production
              alreadyInStore = this.P.vec[prod].getSymbolAmount(target);
              targetAmount -= alreadyInStore #remove what he already has instore from previous periods
              targetComplete = false
              boughtTargets = 0
              buyingFromProducer = 0
              for shelf=1:length(this.B.vec)
                if(this.B.vec[shelf].Product==target) #Search through the shelfs for the required item
                  for offers=1:length(this.B.vec[shelf].Offers.vec)
                    if(targetAmount-boughtTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                      buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
                    else
                      buyingFromProducer = targetAmount-boughtTargets
                    end
                    boughtTargets += buyingFromProducer
                    this.B.vec[shelf].Offers.vec[offers].Units -= buyingFromProducer
                    this.B.vec[shelf].Remaining -= buyingFromProducer
                    this.P.vec[this.B.vec[shelf].Offers.vec[offers].Producer].atomicSale(this.V,this.P,itemsToBuy.vec[item],buyingFromProducer,this.P.vec[prod].ID,this,period)
                    if(boughtTargets==targetAmount)
                      targetComplete = true
                      break
                    end
                  end
                  #After running through all the offers, check if at least the minimum has been accomplished
                  if(boughtTargets>=minAmount)
                    targetComplete = true
                  end
                end
                if(targetComplete)
                  break
                end
              end
            end
          end
          #########################


        end
      end
    end
  ###################################################################################
  ###################################################################################
    this.BuyItemsfromOutputStore = function() #NOT TO USE
      for prod = 1:length(this.P.vec)
        if(this.P.vec[prod].Enabled)
          #Each producer has the oportunity to go through the BList and acquire products
        end
      end
    end
  ###################################################################################
  ###################################################################################
    this.addOffer = function(symbol,available,price,id)
      for cell=1:length(this.B.vec)
        if(this.B.vec[cell].Product==symbol)
          this.B.vec[cell].Offers.addContent(ProductOffer(id,available,0,price))
          this.B.vec[cell].Remaining += available
        end
      end
    end
  ###################################################################################
  ###################################################################################
    this.clearOffers = function()
      for cell=1:length(this.B.vec)
        this.B.vec[cell].Offers.deleteList()
        this.B.vec[cell].Remaining = 0
      end
    end
  ###################################################################################
  ###################################################################################
    this.ControllerAction = function(f,period)
      completedGoals = 0
      for goal=1:length(this.C.Goals.vec)
        target = this.C.Goals.vec[goal].Symbol
        targetAmount = this.C.Goals.vec[goal].Ynom
        minAmount = this.C.Goals.vec[goal].Ymin
        #Search in the BList for the goal, and accquire it
        targetComplete = false
        boughtTargets = 0
        buyingFromProducer = 0
        toDelete = List{Int64}(Int64)
        for shelf=1:length(this.B.vec)
          if(this.B.vec[shelf].Product==target) #this is the shelf we want to analyze
            for offers=1:length(this.B.vec[shelf].Offers.vec)
              if(targetAmount-boughtTargets>=this.B.vec[shelf].Offers.vec[offers].Units)
                buyingFromProducer = this.B.vec[shelf].Offers.vec[offers].Units
              else
                buyingFromProducer = targetAmount-boughtTargets
              end
              boughtTargets += buyingFromProducer
              this.B.vec[shelf].Offers.vec[offers].Units -= buyingFromProducer
              if(this.B.vec[shelf].Offers.vec[offers].Units==0)
                toDelete.addContent(offers)
              end
              #make the transaction
              this.P.vec[this.B.vec[shelf].Offers.vec[offers].Producer].atomicSale(this.V,this.P,target,buyingFromProducer,0,this,period)
              if(boughtTargets==targetAmount)
                targetComplete = true
                break
              end
            end
          end

          for del=1:length(toDelete.vec)
            this.B.vec[shelf].Offers.deleteContent(toDelete.vec[del])
          end

          if(targetComplete)
            break
          end
        end

        #In this stage, the controller already bought what he could
        if(boughtTargets>=minAmount && boughtTargets<=targetAmount)
          completedGoals+=1
        end
      end

      if(length(this.C.Goals.vec) == completedGoals)
        #println("SuperSystem Controller Succeeded");
      else
        println("SuperSystem Controller Not Succeeded ... Quitting");
        quit()
      end
       #Clear the BList
      this.clearOffers()
    end
  ###################################################################################
  ###################################################################################
    #File output functions
  this.PrintSteadyState = function(f) #Prints the steady state objectives of each agent on the simulation file
    for obj=1:length(this.C.Goals.vec)
      quant = this.C.Goals.vec[obj].Amount
      #write(f,this.C.Goals.vec[obj].Symbol,"@$quant/")
    end

    for prod=1:length(this.P.vec)
      id = this.P.vec[prod].ID
      for rule=1:length(this.V.vec[prod].vec)
        if(this.V.vec[prod].vec[rule].Type == "a" || this.V.vec[prod].vec[rule].Type == "c")
            quant = this.V.vec[prod].vec[rule].Consequent.Amount*this.V.vec[prod].vec[rule].Ynom
            #write(f,this.V.vec[prod].vec[rule].Consequent.Symbol,"@$quant/")
        end
      end
    end

  end
  ###################################################################################
  ###################################################################################

  ###################################################################################
  ###################################################################################
    #File output functions
  this.ApplyTaxes = function(f,period) #Controller applies taxes to every producer if applicable
    for prod = 1:length(this.P.vec) # Report of producers current numerarire
        if(this.P.vec[prod].Enabled == true)
          # Test if the numeraire is negative before the application of taxes
          if(this.P.vec[prod].Numeraire<0)
            #Make a credit.

          else
            if(this.P.vec[prod].Internal) #Only apply taxes to internal sector
              tax = this.P.vec[prod].numeraireToBeTaxed*this.C.taxPercentage;
              #Multiply the taxable amount for the pre-regultaed taxing percentage of the controller
              if(tax>0.0) #if the tax is positive, apply taxing
                this.P.vec[prod].Numeraire -= tax;
                @printf(f,"taxes(%d,%d)=%.3f%s",this.P.vec[prod].ID,period,tax,"\n");
              end
              #A producer can also be deleted if its numeraire becomes negative after taxes
              if(this.P.vec[prod].Numeraire<0)
                #Make a credit.


              else
                @printf(f,"numeraires(%d,%d)=%.3f%s",this.P.vec[prod].ID,period,this.P.vec[prod].Numeraire,"\n");
              end
            else
              @printf(f,"numeraires(%d,%d)=%.3f%s",this.P.vec[prod].ID,period,this.P.vec[prod].Numeraire,"\n");
            end
          end
        end
    end
  end
  ###################################################################################
  ###################################################################################
  ############# CHECKSYS FUNCTION ###############
  ###############################################
  this.CheckSys = function(f,period,toConsole)
    if(toConsole) println("↑ Displaying Current SYSTEM information ...") end
    # Print Controller Information
    #=println("→ Controller Info:")
    for i=1:C.Goals.getSize()
      Simb = C.getGoal(i)
      println("    ♦\"",Simb.Symbol,"\": ",Simb.Amount," units @ ",C.getPrice(i))
    end=#

    if(toConsole) println("\n→ Producers Info:") end
    for i=1:this.P.getSize()
      if(this.P.vec[i].Enabled)
        if(toConsole) println("► Producer $i Info [",this.P.vec[i].ID,"]:"); end
        if(toConsole)
          if (this.P.vec[i].Internal==true)
            println("► From Internal Sector.")
          else
            println("► From External Sector.")
          end
        end
        if(toConsole) println("    ♦Numeraire: ",this.P.vec[i].Numeraire) end  #Imprime o numerário do produtor P.vec[i]
        if(period==1) @printf(f,"numeraires_0(%d)=%d\n",i,this.P.vec[i].Numeraire); end  #Output to file numerário do produtor P.vec[i]
        if(toConsole) println("    ♦InputStore [",length(this.P.vec[i].InputStore.vec),"]:"); end
        for j=1:length(this.P.vec[i].InputStore.vec)
          Simb = this.P.vec[i].InputStore.vec[j];
          if(toConsole) println("      ♦\"",Simb.Symbol,"\": ",Simb.Amount," units") end #Imprime as quantidades(Simb.Amount) do produto
          # Simb.Symbol do produtor P.vec[i], que estão na InputStore
          @printf(f,"inputStore_%s(%d,%d)=%d\n",Simb.Symbol,i,period,Simb.Amount); #Sintaxe do Scilab
        end

        if(toConsole) println("    ♦OutputStore [",length(this.P.vec[i].OutputStore.vec),"]:"); end
        for k=1:length(this.P.vec[i].OutputStore.vec)
          Simb = this.P.vec[i].OutputStore.vec[k];
          if(toConsole) println("      ♦\"",Simb.Symbol,"\": ",Simb.Amount," units") end#Imprime as quantidades(Simb.Amount) do produto
          # Simb.Symbol do produtor P.vec[i], que estão na OutputStore
          @printf(f,"outputStore_%s(%d,%d)=%d\n",Simb.Symbol,i,period,Simb.Amount); #Sintaxe do Scilab
        end

        if(toConsole) println("    ♦Credits [",length(this.P.vec[i].Credits.vec),"]:"); end
        for k=1:length(this.P.vec[i].Credits.vec)
          if(toConsole)
            println("      ♦ Credit Nº",k)
            println("         Amount: ",this.P.vec[i].Credits.vec[k].Amount)
            println("         InterestRates: ",this.P.vec[i].Credits.vec[k].InterestRates)
            println("         CreditPayTime: ",this.P.vec[i].Credits.vec[k].CreditPayTime)
            println("         AmountPaid: ",this.P.vec[i].Credits.vec[k].AmountPaid)
            println("         ClientID: ",this.P.vec[i].Credits.vec[k].ClientID)
            println("         LenderID: ",this.P.vec[i].Credits.vec[k].LenderID)
          end
        end
      end
    end

    #Prices output
    if(toConsole) println("► Prices for period $period"); end
    if(period==1) per = 1; else per = period-1 end
    for item=1:length(this.PricingList.vec)
      if(toConsole) println("    ♦",this.PricingList.vec[item].Symbol,"-",this.PricingList.vec[item].PriceList.vec[per]); end
      @printf(f,"price(%d,%d)=%.10f\n",item,period,this.PricingList.vec[item].PriceList.vec[per]); #Sintaxe do Scilab
    end
    #Banks
    if(toConsole) println("► Finacial Institutes for period $period [",length(this.F.vec),"]"); end
    for item=1:length(this.F.vec)
        if(toConsole)
          println("► Bank ",this.F.vec[item].ID,":");
          println("    ♦Assets: ",this.F.vec[item].Assets);
          println("    ♦Liabilities: ",this.F.vec[item].Liabilities);
          #=println("    ♦Credits[",length(this.F.vec[item].Credits.vec),"]: ");
          for k=1:length(this.F.vec[item].Credits.vec)
            if(toConsole)
              println("      ♦ Credit Nº",k)
              println("         Amount: ",this.P.vec[item].Credits.vec[k].Amount)
              println("         InterestRates: ",this.P.vec[item].Credits.vec[k].InterestRates)
              println("         CreditPayTime: ",this.P.vec[item].Credits.vec[k].CreditPayTime)
              println("         AmountPaid: ",this.P.vec[item].Credits.vec[k].AmountPaid)
              println("         ClientID: ",this.P.vec[item].Credits.vec[k].ClientID)
              println("         LenderID: ",this.P.vec[item].Credits.vec[k].LenderID)
            end
          end=#
        end
    end

    if(toConsole) println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n") end
  end
  ###################################################################################
  ###################################################################################
    this.ProcessCredit = function(f,period)
      for prod = 1:length(this.P.vec)
        if(this.P.vec[prod].Enabled)
          for credit=1:length(this.P.vec[prod].Credits.vec)
            amountToPay = (this.P.vec[prod].Credits.vec[credit].Amount/this.P.vec[prod].Credits.vec[credit].CreditPayTime)+
                          ((this.P.vec[prod].Credits.vec[credit].Amount-this.P.vec[prod].Credits.vec[credit].AmountPaid)*
                          this.P.vec[prod].Credits.vec[credit].InterestRates);

            if(this.P.vec[prod].Numeraire-amountToPay>=0)
              this.P.vec[prod].Credits.vec[credit].AmountPaid += (this.P.vec[prod].Credits.vec[credit].Amount/
                                                                this.P.vec[prod].Credits.vec[credit].CreditPayTime);
              #Effect in Client
              this.P.vec[prod].Numeraire -= amountToPay
              this.P.vec[prod].Liabilities -= amountToPay
              #Effect in Lender
              this.F.vec[this.P.vec[prod].Credits.vec[credit].LenderID].Assets -= amountToPay
              this.F.vec[this.P.vec[prod].Credits.vec[credit].LenderID].Liabilities -= amountToPay

              if(this.P.vec[prod].Credits.vec[credit].AmountPaid>=this.P.vec[prod].Credits.vec[credit].Amount)
                  #Delete credit
                  this.P.vec[prod].Credits.deleteContent(credit)
              end
            else
              amountToPay = this.P.vec[prod].Numeraire
              this.DeleteProducer(this.P.vec[prod].ID) #Agent goes bankrupt
              this.F.vec[this.P.vec[prod].Credits.vec[credit].LenderID].Assets -= amountToPay
              this.F.vec[this.P.vec[prod].Credits.vec[credit].LenderID].Liabilities -= amountToPay
            end
          end
        end
      end
    end
  ###################################################################################
  ###################################################################################
    return this,this.K,this.N
  end
end
###################################################################################
###################################################################################
