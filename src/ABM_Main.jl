include("ABM_System.jl")
###################################################################################
#Defines system's initialization file name : System.SystemID.json
#Defines system's output file name : simulation.SystemID.txt
SystemID = "new"; #System Identifier (Simulation ID)
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
f = open(outputFileName,"w");
@printf(f,"SystemIdentifier=%s%s","[]","\n");
@printf(f,"NumberOfPeriods=%d%s",K,"\n");
@printf(f,"NumberOfProducers=%d%s",N,"\n");
@printf(f,"TaxPercentage=%f%s",S.C.taxPercentage,"\n");
@printf(f,"PerturbationType=%s%s","[]","\n");
#Print the symbols associated with product id in prices(id,period)=values
for item=1:length(S.PricingList.vec)
  @printf(f,"priceSymbols(%d)=\"%s\"\n",item,S.PricingList.vec[item].Symbol); #Sintaxe do Scilab
end

CheckSys(S.C,S.P,S.V,1,f,false,S); #Prints to output file the stores values of each producer STARTING POINT

#CheckSys(S.C,S.P,S.V,1,f,true,S); #Prints to output file the stores values of each producer STARTING POINT
#CheckRules(S.V)

println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println("  Starting Simulation ... $K Periods");
println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")

for period = 1:K
  S.NecessaryRulesConsumption(f,period) #Consumption of Necessary Rules
  S.ProductionAnnouncement(f,period) #Producers announce what they can produce,
  S.BuyItems(f,period) #Producers buy what they want/need from other producers
  S.ControllerAction(f,period)
  S.ApplyTaxes(f,period)
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
