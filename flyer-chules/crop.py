from PIL import Image
U="/root/.claude/uploads/5ecd1ae6-d403-5775-9c35-a3f546b77f5b/"
canva=Image.open(U+"79e0618a-image.png").convert("RGB")
real=Image.open(U+"8cd3b1a7-image.jpg").convert("RGB")
promo=Image.open(U+"140ab039-image.png").convert("RGB")
C={
 "merengue-choco":(108,87,319,288),
 "coco-ddl":(352,87,563,288),
 "canoncitos-ddl-choco":(605,87,819,292),
 "canoncitos-ddl":(853,87,1067,291),
 "pastafrola":(111,406,319,603),
 "pastafrola-ddl":(352,406,560,603),
 "palmeritas":(643,413,819,589),
 "alfajores":(852,407,1061,606),
 "masas-banadas":(108,729,312,923),
 "anillos-ddl":(364,732,562,923),
 "masas-glaseadas":(611,732,808,923),
 "logo":(872,950,1062,1132),
}
for k,b in C.items(): canva.crop(b).save(f"img/{k}.jpg",quality=95)
real.crop((0,0,1600,1330)).save("img/postres.jpg",quality=92)
promo.crop((110,330,910,538)).save("img/potes.jpg",quality=95)
promo.crop((88,1225,345,1480)).save("img/alfajor-mediano-choco.jpg",quality=95)
promo.crop((686,1225,940,1480)).save("img/alfajor-mediano-maicena.jpg",quality=95)
