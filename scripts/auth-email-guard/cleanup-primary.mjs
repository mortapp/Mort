export async function completeCleanup(primary,steps,emit=row=>console.error('Fixture cleanup failure: '+JSON.stringify(row))){
 let firstCleanup;
 for(let index=0;index<steps.length;index++){
  try{await steps[index]();}
  catch(error){firstCleanup??=error;emit({step:index+1,primaryPreserved:Boolean(primary),name:['Error','TypeError','AssertionError'].includes(error.name)?error.name:'unclassified'});}
 }
 if(primary)throw primary;
 if(firstCleanup)throw firstCleanup;
}
