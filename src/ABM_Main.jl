include("ABM_System.jl")
###################################################################################
#Defines system's initialization file name : System.SystemID.json
#Defines system's output file name : simulation.SystemID.txt
SystemID = "TestD0"; #System Identifier (Simulation ID)
###################################################################################
#Main Simulation Program
println("     ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println("Agent-Based Modelling Simulator");
time = now();
println("Exec @ $time");
println("Running the following test: $SystemID");
println("     ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")

outputFileName = string("../outputs/simulation.",SystemID,".txt");
systemConfigFileName = string("../configs/System.",SystemID,".json");

S,K,N= SuperSystem(systemConfigFileName);
println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println("  Starting Simulation ... $K Periods");
println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")

f = open(outputFileName,"w");
@printf(f,"SystemIdentifier=%s%s","[]","\n");
@printf(f,"NumberOfPeriods=%d%s",K,"\n");
@printf(f,"NumberOfProducers=%d%s",N,"\n");
@printf(f,"TaxPercentage=%f%s",S.C.taxPercentage,"\n");
@printf(f,"PerturbationType=%s%s","[]","\n");
#Print the symbols associated with product id in prices(id,period)=values
for item=1:length(S.PricingList.vec)
  @printf(f,"priceSymbols(%d)=%s\n",item,S.PricingList.vec[item].Symbol); #Sintaxe do Scilab
end

CheckSys(S.C,S.P,S.V,1,f,false,S); #Prints to output file the stores values of each producer STARTING POINT
for period = 1:K
  #@printf(f,"@PERIOD_START:%d%s",period,"\n");
    #println("→ Simulation Period: $period\n");
  #1. In the first step, the necessary rules in all producers operate.
    #println("\n☼ Necessary Rules Phase")
  S.NecessaryRulesConsumption(f,period) #Consumption of Necessary Rules
  #CheckSys(S.C,S.P,S.V);
  #2. In the second step, all producers make offers for production and price of possible rules output.
    #println("\n☼ Production Announcement Phase")
  #S.SaleableRulestoOutputStore() #Producers produce what they can produce to their output stores
  # and make a product offer on the BList, but already produced
  S.ProductionAnnouncement(f,period) #Producers announce what they can produce,
  #CheckSys(S.C,S.P,S.V);
  #filling up the BList with their sell offers
  #3. In the third step, all producers decide what to buy and try to buy what they decided; the controller
  # buys the products it commanded, up to the numbers set for the cycle.
    #println("\n☼ Purchase Items Phase")
  S.BuyItems(f,period) #Producers buy what they want/need from other producers
  #S.BuyingOffers(f); S.BuyFromOrders(f);
  #CheckSys(S.C,S.P,S.V);
  # as the controller gets what it demanded
  #After all purchases append, we should clear the Blist, to clear the items that
  #wasnt sold by the producers
    #println("\n☼ Controller Phase")
  S.ControllerAction(f,period)
  #CheckSys(S.C,S.P,S.V);
    #println("\n▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n")
    #println("▬ Period $period Ended\n\n");
  S.ApplyTaxes(f,period)
  #@printf(f,"@PERIOD_END%s","\n");

  #S.ProcessCredit(f,period);

  CheckSys(S.C,S.P,S.V,period+1,f,false,S); #Prints to output file the stores values of each producer
  #period+1 and not period because the minimum array index in Scilab is 1
end

println("  ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println(" Simulation terminated");
println("  ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")
#CheckSys(S.C,S.P,S.V,K,f,true); #Prints to console the stores values of each producer END POINT
#@printf(f,"@SIMULATION_END%s","\n");
close(f)
quit()


###################################################################################
# PROCEDURE FOR EACH PERIOD
#1. In the first step, the necessary rules in all producers operate.
#2. In the second step, all producers make offers for production and price of possible rules output.
#3. In the third step, all producers decide what to buy and try to buy what they decided; the controller
# buys the products it commanded, up to the numbers set for the cycle.
#4. In the fourth step, the controller applies taxed to all producers.
#5. In the fifth step, the credit is processed between lenders and borrowers
###################################################################################
