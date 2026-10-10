using Mono.Cecil;
using Mono.Cecil.Cil;
using System.Security.Cryptography;

var source=args[0]; var output=args[1];
if(Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(source)))!="08489C29167625D19E7AA76F1B42500782EBF979FE9B840360D72A76D17C6B36")throw new Exception("Unsupported input: requires Chinese 2610 v1.0.0/v1.1.0 unmodified assembly");
var resolver=new DefaultAssemblyResolver();resolver.AddSearchDirectory(Path.GetDirectoryName(source));
var a=AssemblyDefinition.ReadAssembly(source,new ReaderParameters{AssemblyResolver=resolver}); var m=a.MainModule;
TypeDefinition T(string n)=>m.Types.Single(t=>t.Name==n);
var core=resolver.Resolve(m.AssemblyReferences.Single(r=>r.Name=="UnityEngine.CoreModule")).MainModule;
var audio=resolver.Resolve(m.AssemblyReferences.Single(r=>r.Name=="UnityEngine.AudioModule")).MainModule;
MethodReference Ref(ModuleDefinition module,string type,string name,int count)=>m.ImportReference(module.Types.Single(t=>t.FullName==type).Methods.Single(x=>x.Name==name&&x.Parameters.Count==count));
var setTime=Ref(core,"UnityEngine.Time","set_timeScale",1);var getTime=Ref(core,"UnityEngine.Time","get_timeScale",0);
var inputType=m.GetMemberReferences().OfType<MethodReference>().First(x=>x.DeclaringType.FullName=="UnityEngine.Input").DeclaringType.Resolve();
var getKey=m.ImportReference(inputType.Methods.Single(x=>x.Name=="GetKeyDown"&&x.Parameters[0].ParameterType.FullName=="UnityEngine.KeyCode"));
var pitch=Ref(audio,"UnityEngine.AudioSource","set_pitch",1);
if(m.Types.Any(t=>t.Name=="AchievementSpeedMod"))throw new Exception("Already patched");
var helper=new TypeDefinition("","AchievementSpeedMod",TypeAttributes.Public|TypeAttributes.Abstract|TypeAttributes.Sealed,m.TypeSystem.Object);m.Types.Add(helper);
var enabled=new FieldDefinition("Enabled",FieldAttributes.Public|FieldAttributes.Static,m.TypeSystem.Boolean);helper.Fields.Add(enabled);
MethodDefinition Add(string name,TypeReference result){var f=new MethodDefinition(name,MethodAttributes.Public|MethodAttributes.Static,result);helper.Methods.Add(f);return f;}
var cctor=Add(".cctor",m.TypeSystem.Void);cctor.Attributes|=MethodAttributes.SpecialName|MethodAttributes.RTSpecialName;
var il=cctor.Body.GetILProcessor();il.Emit(OpCodes.Ldc_I4_1);il.Emit(OpCodes.Stsfld,enabled);il.Emit(OpCodes.Ret);
MethodDefinition Factor(string name,float fast){var f=Add(name,m.TypeSystem.Single);var p=f.Body.GetILProcessor();var normal=Instruction.Create(OpCodes.Ldc_R4,1f);p.Emit(OpCodes.Ldsfld,enabled);p.Emit(OpCodes.Brfalse,normal);p.Emit(OpCodes.Ldc_R4,fast);p.Emit(OpCodes.Ret);p.Append(normal);p.Emit(OpCodes.Ret);return f;}
var speed=Factor("Speed",3f);var movement=Factor("MovementStep",2f/3f);
var tick=Add("Tick",m.TypeSystem.Void);il=tick.Body.GetILProcessor();var check=Instruction.Create(OpCodes.Call,getTime);var end=Instruction.Create(OpCodes.Ret);
il.Emit(OpCodes.Ldc_I4,287);il.Emit(OpCodes.Call,getKey);il.Emit(OpCodes.Brfalse,check);il.Emit(OpCodes.Ldsfld,enabled);il.Emit(OpCodes.Ldc_I4_0);il.Emit(OpCodes.Ceq);il.Emit(OpCodes.Stsfld,enabled);il.Append(check);il.Emit(OpCodes.Ldc_R4,0f);il.Emit(OpCodes.Ble,end);il.Emit(OpCodes.Call,speed);il.Emit(OpCodes.Call,setTime);il.Append(end);
var gameUpdate=T("Game").Methods.Single(x=>x.Name=="Update");gameUpdate.Body.GetILProcessor().InsertBefore(gameUpdate.Body.Instructions[0],Instruction.Create(OpCodes.Call,tick));
var hero=T("HeroController").Methods.Single(x=>x.Name=="FixedUpdate");il=hero.Body.GetILProcessor();int loads=0;
foreach(var ins in hero.Body.Instructions.ToArray())if(ins.OpCode==OpCodes.Ldfld&&ins.Operand is FieldReference f&&new[]{"walkSpeed","runSpeed","curSickWalkSpeed"}.Contains(f.Name)){var call=Instruction.Create(OpCodes.Call,movement);il.InsertAfter(ins,call);il.InsertAfter(call,Instruction.Create(OpCodes.Mul));loads++;}
if(loads!=4)throw new Exception($"Unexpected movement load count {loads}");
var voice=T("VoiceController");var play=voice.Methods.Single(x=>x.Name=="PlaySound");
var getAudio=(MethodReference)play.Body.Instructions.First(x=>x.Operand is GenericInstanceMethod g&&g.Name=="GetComponent"&&g.GenericArguments[0].FullName=="UnityEngine.AudioSource").Operand;
var update=voice.Methods.Single(x=>x.Name=="Update");il=update.Body.GetILProcessor();var first=update.Body.Instructions[0];
foreach(var ins in new[]{Instruction.Create(OpCodes.Ldarg_0),Instruction.Create(OpCodes.Call,getAudio),Instruction.Create(OpCodes.Call,speed),Instruction.Create(OpCodes.Callvirt,pitch)})il.InsertBefore(first,ins);
il=play.Body.GetILProcessor();var playCall=play.Body.Instructions.Single(x=>x.Operand is MethodReference r&&r.DeclaringType.FullName=="UnityEngine.AudioSource"&&r.Name=="Play");
foreach(var ins in new[]{Instruction.Create(OpCodes.Dup),Instruction.Create(OpCodes.Call,speed),Instruction.Create(OpCodes.Callvirt,pitch)})il.InsertBefore(playCall,ins);
Directory.CreateDirectory(Path.GetDirectoryName(output));a.Write(output);
using var verify=AssemblyDefinition.ReadAssembly(output);
if(verify.MainModule.Types.Single(t=>t.Name=="AchievementSpeedMod").Methods.Count!=4)throw new Exception("Verification failed");
var runtime=System.Reflection.Assembly.LoadFile(Path.GetFullPath(output));var runtimeHelper=runtime.GetType("AchievementSpeedMod",true)!;
float Evaluate(string method)=>(float)runtimeHelper.GetMethod(method)!.Invoke(null,null)!;
if(Evaluate("Speed")!=3f||Math.Abs(Evaluate("MovementStep")-2f/3f)>0.00001f)throw new Exception("Fast mode test failed");
runtimeHelper.GetField("Enabled")!.SetValue(null,false);
if(Evaluate("Speed")!=1f||Evaluate("MovementStep")!=1f)throw new Exception("Normal mode test failed");
runtimeHelper.GetField("Enabled")!.SetValue(null,true);
if(getKey.Parameters[0].ParameterType.FullName!="UnityEngine.KeyCode")throw new Exception("Keyboard overload verification failed");
Console.WriteLine($"Patched: movement 2x, timeline/voice 3x, F6 toggle; movement sites={loads}; SHA256={Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(output)))}");
