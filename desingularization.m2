newPackage(
    "Desingularization",
    Version => "0.01",
    Date => "October 41, 2029",
    Authors => {
	{Name => "Daniel Apsley", Email => "apsley@math.utah.edu", HomePage => "https://www.math.utah.edu/~apsley/"}, 
    {Name => "Emelie Arvidsson", Email => "arvidsson@utah.edu", HomePage => "https://www.emeliearvidsson.com/"},
    {Name => "Joseph Sullivan", Email => "jsullivan@math.utah.edu", HomePage => "https://partiallyordered.com/"}},
    Headline => "Resolving Singularities in Macaulay2",
    Keywords => {"Algebraic Geometry"},
    PackageImports => { "ReesAlgebra", "Divisor", "PrimaryDecomposition" },
    DebuggingMode => true,
    Reload=>true
    );

export {
-- Methods
"variableChange", 
"preImage",
"inverseMap", 
"prunedringMap", 
"blowupCharts",
"totalTransform",
"strictTransform",
"isResolved",
"isSmoothSurface",
"desingStep",
-- Options
"Exceptional",
"Divisorial",
-- Types and Terms
"DesingularizationStep",
"Charts",
"StepNumber",
"IntersectionMatrix",
"Exceptionals"
};

-- Change the above as needed! We will probably take out a good chunk of these before submission. 

variableChange = method();
variableChange(PolynomialRing, Symbol) := (R, t) -> (
	oldVars := flatten entries vars R;
	n := #(oldVars);
	coeffRing := coefficientRing(R);
	freshRing := coeffRing[t_1..t_n];
	phi := map(freshRing, R, vars freshRing);
	phi
);

variableChange(QuotientRing, Symbol) := (R, t) -> (
	oldVars := flatten entries vars R;
	n := #oldVars;
	coeffRing := coefficientRing(R);
	freshPolyRing := coeffRing[t_1..t_n];
	psi := map(R, freshPolyRing, oldVars);
	freshIdeal := ker psi;
	freshRing := freshPolyRing/freshIdeal;
	phi := map(freshRing, R, vars freshRing);
	phi
);


variableChange(Ideal, Symbol) := (I, t) -> (
	R := ring(I);
	phi := variableChange(R, t);
	phi(I)
);

-- Perhaps the function finding the 'pruning map' exists already. I couldn't find it so I made some. Excuse the bit of space.

preImage = method();
preImage(RingMap, Ideal) := (phi, I) -> (
    projection := map(target(phi)/I, target(phi));
    kernel (projection*phi) 
);


inverseMap = method();
inverseMap(RingMap) := phi -> (
    if kernel phi != ideal(substitute(0, source phi)) then (
        error "The map is not invertible."
    );
    flatRing := (flattenRing(target phi))#0;
    varlist := flatten entries vars flatRing;
    images := {};
    for x in varlist do (
        J := preImage(phi, ideal(substitute(x, target phi)));
        gensJ := flatten entries gens J;
        images = append(images, gensJ#0);
    );
    map(source phi, target phi, images)
);

--TODO: add an error for when J is not principal. 

prunedringMap = method();
prunedringMap(QuotientRing) := R -> (
    prunedRing := prune R; 
    badvars := flatten entries vars prunedRing;
    goodvars := {};
    for x in badvars do (
        goodvars = append(goodvars, substitute(x, R))
    );
    phi := map(R, prunedRing, goodvars);
    inverseMap(phi)
);


blowupCharts = method(Options => {Exceptional => true});

blowupCharts(Ideal, ZZ, Symbol) := opts -> (J, m, s) -> (
	a := reesIdeal(J); -- Ideal of rees algebra in affine space over A.
	A := ring(J);
	B := ring(a);
	StructureB := map(B, A, {});
	n := #gens B;

	if (m < 1) or (m > n) then (
		error "chart number out of range";
	);
    u := local u;
	AffineRing := A[u_1..u_(n - 1)];
	structureMap := map(AffineRing, A, {});

	coolBeans := flatten flatten {toList(u_1..u_(m - 1)), 1, toList(u_m..u_(n - 1))};
	phi := map(AffineRing, B, coolBeans);
	quotient := AffineRing/phi(a);
	projection := map(quotient, AffineRing, {});
	preoutputMap := prunedringMap(quotient)*projection * structureMap;
    outputMap := variableChange(target(preoutputMap), s) * preoutputMap;
    exceptionalIdeal := trim outputMap(J);
    if opts#Exceptional === true then (
        return {outputMap, exceptionalIdeal};
    );
    if opts#Exceptional === false then (
        return outputMap;
    );
);


blowupCharts(Ideal, ZZ) := opts -> (J, m) -> (
    u := local u;
    return blowupCharts(J, m, u);
);

blowupCharts(Ideal, Symbol) := opts -> (I, s) -> (
	listofCharts := {};
	for i from 1 to (#(flatten entries gens I)) do (
		listofCharts = append(listofCharts, blowupCharts(I, i,s, opts))
	);
	listofCharts
);

blowupCharts(Ideal) := opts -> I -> (
    u := local u;
    blowupCharts(I, u)
);


totalTransform = method(Options => {Divisorial => false});

totalTransform(Ideal, Ideal, ZZ) := opts -> (I, J, m) -> (
	chartMap := blowupCharts(J, m, Exceptional => false);
    if opts#Divisorial === false then (
        return chartMap(I);
    );
	if opts#Divisorial === true then (
        return divisor(chartMap(I));
    );
);

totalTransform(Ideal, Ideal) := opts -> (I, J) -> (
	n := #(flatten entries gens J);
	outputlist := {};
	for i from 1 to n do (
		outputlist = append(outputlist, totalTransform(I, J, i, opts));
	);
	outputlist
);

strictTransform = method(Options => {Divisorial => false});

strictTransform(Ideal, Ideal, ZZ) := opts -> (I, J, m) -> (
	idealList := primaryDecomposition(totalTransform(I, J, m));
    R := ring(idealList#0);
    exceptionalLocus := (blowupCharts(J, m, Exceptional => true))#1;
    for a in idealList do (
        if radical(a) == sub(exceptionalLocus, R) then (
            idealList = delete(a, idealList);
        );
    );
    outputIdeal := ideal(substitute(1, R));
    for a in idealList do (
        outputIdeal = a*outputIdeal;
    );
    if opts#Divisorial === false then (
        return outputIdeal
    );
    if opts#Divisorial === true then (
        return divisor(outputIdeal)
    );
   );

strictTransform(Ideal, Ideal) := opts -> (I, J) -> (
	n := #(flatten entries gens J);
	L := {};
	for i from 1 to n do (
		littleL := strictTransform(I,J,i, opts);
		L = append(L, littleL);
	);
	L
);


isSmoothSurface = method();
isSmoothSurface(Ring, Ideal) := (R,I) -> (
    d := divisor(I);
    isSNC(d)
);

isSmoothSurface(Ring, WeilDivisor) := (R,d) -> (
    isSNC(d)
)

isResolved = method(Options => {Exceptional => false});

isResolved(Ideal, ZZ) := opts -> (I, n) -> (

);

-- TODO: make this function! 
DesingularizationStep = new Type of MutableHashTable;
desingStep = method();

desingStep(Ring) := R -> (
	new DesingularizationStep from {Charts => {map(R, R, flatten entries vars R)}, IntersectionMatrix => matrix(0), StepNumber => 0, Exceptionals => {()}}
);
beginDocumentation()

blowupCharts(DesingularizationStep, Ideal) := opts -> (S, J) -> (
    newStepNumber := S#StepNumber + 1;
    oldExceptionals := S#Exceptionals;
    oldCharts := S#Charts;
    oldTargets := {};
    for f in oldCharts do (
        oldTargets = append(oldTargets, target(f))
    );
    Jrings := 0;
    Jringindex := -1;
    for R in oldTargets do (
        Jringindex = Jringindex + 1;
        if ring(J) === R then (
            Jrings = Jrings + 1;
        );
    );
    if Jrings != 1 then (
        error "expected ideal of the same ring"
    );
    
    prenewvariable := concatenate{"T", toString(newStepNumber)};
    newvariable := getSymbol prenewvariable;
    newblowupcharts := blowupCharts(J, newvariable, Exceptional => true);
    oldseq := (oldExceptionals)#Jringindex;

    chartstoappend := {};
    exceptionalstoappend := {};
    Cindex := -1;
    for C in newblowupcharts do (
        Cindex = Cindex + 1;
        f := C#0;
        localExcideal := C#1;
        freshseq := ();
        R := target(f);
        for exIdeal in oldseq do (
            idealList := primaryDecomposition(f(exIdeal));
            for a in idealList do (
                if a == localExcideal then (
                    idealList = delete(a, idealList);
                );
            );
            transformedExc := ideal(sub(1, R));
            for a in idealList do (
                transformedExc = a*transformedExc; 
            );
            freshseq = append(freshseq, transformedExc);
        );
        freshseq = append(freshseq, C#1);
        chartstoappend = append(chartstoappend, f*(oldCharts#Jringindex));
        exceptionalstoappend = append(exceptionalstoappend, freshseq);
    );

    newCharts := flatten replace(Jringindex, chartstoappend, oldCharts);
    newExceptionals := flatten replace(Jringindex, exceptionalstoappend, oldExceptionals);

    new DesingularizationStep from {Charts => newCharts, IntersectionMatrix => matrix(0), StepNumber => newStepNumber, Exceptionals => newExceptionals}
);

totalTransform(DesingularizationStep, Ideal) := opts -> (S, I) -> (
    listofCharts := S#Charts;
    outputList := {};
    if opts#Divisorial === false then (
        for phi in listofCharts do (
            outputList = append(outputList, phi(I))
        );
    );
    if opts#Divisorial === true then (
        for phi in listofCharts do (
            outputList = append(outputList, divisor(phi(I)))
        );
    );
    outputList
);

strictTransform(DesingularizationStep, Ideal) := opts -> (S, I) -> (
    listofCharts := S#Charts;
    exceptionalDivisors := S#Exceptionals;
    numofCharts := #listofCharts;
    preoutputList := {};
    for i from 0 to (numofCharts - 1) do (
        exceptionalLoci := exceptionalDivisors#i;
        phi := listofCharts#i;
        idealList := primaryDecomposition(phi(I));
        R := ring(idealList#0);
        for a in idealList do (
            for E in exceptionalLoci do (
                if radical(a) == sub(E, R) then (
                    idealList = delete(a, idealList);
                );
            );
        );
        outputIdeal := ideal(sub(1, R));
        for a in idealList do (
            outputIdeal = a*outputIdeal;
        );
        preoutputList = append(preoutputList, outputIdeal);
    );
    preoutputList
);


doc ///
    Key 
        prunedringMap
        (prunedringMap, QuotientRing)
    Headline
        the pruning isomorphism. 
    Usage
        prunedringMap(R)
    Inputs
        R: QuotientRing
    Outputs
        : RingMap
    Description
        Text
         Outputs the isomorphism between a quotient ring and its pruning.  
    SeeAlso

///

doc ///
    Key 
        blowupCharts
        (blowupCharts, Ideal, ZZ)
        (blowupCharts, Ideal)
        [blowupCharts, Exceptional]
    Headline
        Blowing up ideals of affine varieties. 
    Usage
        blowupChart(J, n, Exceptional => b)
        blowupChart(J)
    Inputs
        J: Ideal
        n: ZZ
        b: Boolean
    Outputs
        : List
        : List
    Description
        Text
         Finds the charts and exceptional divisors of the blowup of an affine scheme along an ideal. Outputs the n'th chart of the blowup of ring(J) along J. It will output a list of ring maps, together with ideals of the target which define the exceptional locus 
    SeeAlso

///

doc ///
    Key 
        totalTransform
        (totalTransform, Ideal, Ideal, ZZ)
        (totalTransform, Ideal, Ideal)
        [totalTransform, Divisorial]
    Headline
        Transporting ideals along blowups.
    Usage
        totalTransform(I, J, n, Divisorial => b)
        totalTransform(I, J, Divisorial => b)
    Inputs
        I: Ideal
        J: Ideal
        n: ZZ
        b: Boolean
    Outputs
        : Ideal
        : List
    Description
        Text
         Computes the total transform of I in the blowup along J. If X' -> X is the blowup and a is the ideal, this computes the local description of a*O_X'. If Divisiorial is set to true, this outputs the associated divisor (resp. list of divisors).
    SeeAlso
        strictTransform
///

doc ///
    Key 
        strictTransform
        (strictTransform, Ideal, Ideal, ZZ)
        (strictTransform, Ideal, Ideal)
        [strictTransform, Divisorial]
    Headline
        The non-exceptional part of the total transform. 
    Usage
        strictTransform(I, J, n, Divisorial => b)
        strictTransform(I, J, Divisorial => b)
    Inputs
        I: Ideal
        J: Ideal
        n: ZZ
        b: Boolean
    Outputs
        : Ideal
        : List
    Description
        Text
         Computes the strict transform of I in the blowup along J. That is, it factors the exceptional part out of the total transform. The option determines whether to output an ideal or the associated divisor. 
    SeeAlso
        totalTransform
///


TEST ///
   
///



end--

-- T = QQ[x,y];
-- J = ideal(x,y);
-- I = ideal(x^3 - x^2 + y^2);

 -- I defines a nodal cubic resolved by one blow-up at the origin. The following command computes the ideal of the strict transform of I in the first chart.

-- strictTransform(I, J, 1)
-- T = QQ[x,y,z];
-- I = ideal(x^2*z - y^2); -- whitney umbrella

-- isResolved(I, 3)
-- isResolved(I, 2)

-- Testing the prune map function

-- R = QQ[x,y,z];
-- m = ideal(x,y,z);
-- testcharts = affineCharts(m);
-- f = testcharts#0;
-- Q = target f;
-- prunedringMap(Q);

-- TODO: Add the following tests

-- Check the strict transform of reducible ideals like x*y + y^3. Better yet if the singular locus is not the origin. 


