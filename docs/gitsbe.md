# Gitsbe {-}

[Gitsbe] is an acronym for *Genetic Interactions To Specific Boolean Equations*.
This module defines boolean models compliant with observed behavior (e.g. steady state or perturbation data) using an automated, model parameterization genetic algorithm.



The code of the package is available in [Bitbucket](https://bitbucket.org/asmundf/gitsbe/src/master/).
This documentation is for the software version `1.2.11`

## Description {-}

The model interactions (taken from a network file, see [inputs] section) are first assembled to logical boolean equations, based on a **default equation** relating a node with its regulators:

<div class="blue-box">
<b><i>Target *= (A or B or C) and not (D or E or F)</i></b>
</div>

where the *activating* regulators `A`, `B` and `C` and the *inhibitory* regulators `D`, `E` and `F` of a target node are combined with logical `or` operators between them and connected with the `and not` *link operator*. 
Thus, the state of the target node can be calculated using boolean algebra (0 means *inhibited*, 1 *active*).

----

[Gitsbe] uses a **genetic algorithm** to generate and parameterize boolean models that fit to the [training data] observations.
First, an initial generation of models is formulated from the input model, where a large number of **mutations** to the parameterization is [introduced](#genAlgoParams): for example, randomly selected equations are mutated to use the `or not` link operator instead of the `and not`.
Then for each model, a *fitness* score is computed as the weighted average over all fitness values for each observation that is specified in the [training data] file. 
During this step, the calculation of the [models attractors](#attractor-tool) takes place.
The models that achieve the highest fitness scores will be **selected** for the next generation (see [respective configuration options](#genAlgoParams)) and will be used during the **crossover phase** to exchange logical equations between them (also including themselves - enabling *asexual reproduction*!). 
This is how the models of the new generation are determined.
After that, the **mutation phase** is repeated as described above, followed by the calculation of the attractors and the subsequent **selection phase**.

After a non-negative total fitness score is obtained for the worst of the best models in the current generation, the number of mutations introduced per generation is reduced by a user-specified factor (see [options](#genAlgoParams)). 
The whole **evolution** process is halted either when a user-specified fitness threshold is reached or when the (also user-defined) maximum number of generations had been spanned.
The highest-fitness models of the last generation are stored in a `models` directory (see [Outputs]).
Different simulations of the **evolution** process can be run from the initial model (even in *parallel* utilizing all available cores), using a different seed per simulation and thus creating different parameterized output models in each case.

## Installation and Usage {-}

### Install {-}

Prerequisites: `maven 3.6.0` and `Java 8`.

Installation commands:
```
git clone https://bitbucket.org/asmundf/gitsbe.git
mvn clean install
```

<div class="orange-box">
Note that [Gitsbe] calculates attractors for the boolean models it generates using either the [BNReduction tool](https://github.com/alanavc/BNReduction) [@Veliz-Cuba2014] or the [BioLQM](https://github.com/colomoto/bioLQM) Java library [@Naldi2018]. BioLQM is included by default in the code.
The BNReduction tool has to be manually installed following the [respective documentation](https://bitbucket.org/asmundf/druglogics_dep/src/master/). 
</div>

### Example {-}

The recommended way to run [Gitsbe] is to use it's `Launcher`. 
From the root directory of the repo run:
```
cd example_run_ags
java -cp ../target/gitsbe-1.2.11-jar-with-dependencies.jar eu.druglogics.gitsbe.Launcher --project=test --network=toy_ags_network.sif --trainingdata=toy_ags_training_data.tab --config=toy_ags_config.tab --modeloutputs=toy_ags_modeloutputs.tab
```

or run the `mvn` profile directly (same input as the command above through the `pom.xml`):
```
mvn compile -P runExampleAGS
```

### Inputs {-}

Running the [Gitsbe] `Launcher` with no parameters, generates a **usage message** with the available options.
The **required** parameters are:

- `--network`: network file (in Cytoscape's `.sif` format, *tab*-delimited, with binary signed and directed interactions)
- `--trainingdata`: [training data file](#training-data)
- `--modeloutputs`: [model outputs file](#modeloutputs)
- `--config`: [configuration file](#gitsbeConfig)

The **non-required** parameters are:

- `--project`: the project name which is used as the name of the directory where the [outputs] will be stored.
- `--drugs`: [drugpanel file](#drugpanel): this is required only when the [training data] observations include either drug perturbation or drug synergy conditions.

### Outputs {-}

The expected generated outputs of the `Launcher` are:

- A **models directory** with files in `.gitsbe` format (or [other formats](#export-options) as well if properly specified), which represent the boolean models that best fitted to the configuration and training data that the simulation of the genetic algorithm was based on.
- A **summary file** that includes the models' fitness evolution throughout the genetic algorithm's generations.
- The **initial boolean model** exported in many [standard formats](#export-options) (e.g. `.gitsbe`, `.sif`, `.ginml`).

## Training Data {-}

The training data file includes specific *condition-response* pairs (**observations**) which are used to calculate the fitness of the boolean models during the **evolution** process of the [genetic algorithm](#description). 
For each observation, a different *fitness* score is calculated.
Every fitness score is between $0$ (no fitness at all) and $1$ (perfect fitness).
The format of each observation is:

<div class="blue-box">
<b>Condition</b><br>
\<data\><br>
<b>Response</b><br>
\<data\><br>
<b>Weigth:</b>\<number\><br>
</div>

The **weight** numbers (can be continuous values) are used after each individual observation *fitness* score has been calculated, to derive a total average weighted fitness score for the model which is *fitted* to the traning data.

----

The currently supported observations are:

1. Unperturbed Condition - Steady State Response

<div class="blue-box">
<b>Condition</b><br>
-<br>
<b>Response</b><br>
A:0 B:1 C:0 D:0.453<br>
<b>Weigth:</b>1<br>
</div>

This is the most commonly used training option.
Note that the response values are *tab-separated* and that the numbers assinged to each of the entities, define an activity value in the $[0,1]$ interval (continuous values are allowed).
The entities have to be nodes from the [initial network](#inputs), otherwise they are ignored.
Thus, a boolean model with it's attractors calculated, will have a fitness score for this kind of observation that describes the **closeness of it's attractors to the specified steady state response**.

For example, if a boolean model has only 1 trapspace attractor, on which the nodes {A,B,C,D} have values {0,1,-,-}, the fitness would be:
$$fitness=\frac{\sum matches}{\#responses}=\frac{1+1+(1-abs[0-0.5])+(1-abs[0.453-0.5])}{4}=\frac{3.453}{4} \simeq 0.86$$

If a model has multiple attractors, then first we find the average number of matches across all attractors and then divide by the number of responses.
For example, if the previous model had one more attractor for which the nodes perfectly matched the observed responses (so $4$ in total matches) we would have an average value of matches across the two attractors equal to $(4+3.453)/2=3.7265$ and a *fitness* thus equal to $3.7265/4\simeq0.93$ (which makes sense since the second attractor matched better the observed state and thus **boosted** the fitness).

2. Unperturbed Condition - `globaloutput` Response

<div class="blue-box">
<b>Condition</b><br>
-<br>
<b>Response</b><br>
globaloutput:1<br>
<b>Weigth:</b>1<br>
</div>

This training option pretty much translates to: **if I leave the system unperturbed, it continues proliferating** - a direct description of a cancer cell network system.
So, with this type of observation we can train models to match a **growing cell/proliferation profile**!
Note though that the observed `globaloutput` response can take any value in the $[0,1]$ interval (from a cell death state to a cell proliferation state so to speak).

In order to find the *fitness* of a boolean model to this kind of observation, we first calculate it's attractors, compute it's *predicted* `globaloutput` using Equation No. \@ref(eq:modeloutputs) (see [ModelOutputs]) and then calculate:
$$fitness=1-abs(gl_{obs}-gl_{pred})$$

3. Simple/Multiple knockout/over-expression Condition - `globaloutput` Response

4. Single Drug perturbation Condition - `globaloutput` Response

5. Double Drug synergy Condition - relative `globaloutput` Response


Drug(A+B) < min(Drug(A),Drug(B)) or Drug(A+B) < product(Drug(A),Drug(B))


- If the condition is for a **specified perturbation**, then an expected 
**global output value** is computed by integrating a weighted score across the 
states of model output nodes. This is contrasted with the observed global output 
response value in the training data (for that particular condition) to produce 
the sub-fitness score. A fitness of 1 means that the expected and observed 
global output scores are the same.


## Modeloutputs {-}

The `modeloutputs` is an input file that is used by both [Gitsbe] and [Drabme]. 
In the file, **network nodes with their respective integer weights** are defined, like in the example below: 

<div class="blue-box">
RPS6KA1 &emsp; 1<br>
MYC &emsp; 1<br>
TCF7 &emsp; 1<br>
CASP8 &emsp; -1<br>
CASP9 &emsp; -1<br>
FOXO3 &emsp; -1<br>
</div>

The nodes are *tab-separated* with the values and indicate the entities that directly influence the cell's global *signaling output* or *growth*: nodes that have a *negative* output value weight contribute to **cell death** through various means (e.g. `CASP8`) and nodes that have a *positive* value contribute to **cell proliferation** (e.g. `MYC`). 
We allow only integer values for the node weights while their magnitude allows to distinct each node by how much do they influence cell death/proliferation: for example, a weight of $-2$ for the node `CASP8` would make it twice more important for cell death as a node who has a value of $-1$.

So, for each [training data] observation where we need to calculate a `globaloutput` value for a boolean model and for which we already have it's attractors (stable states or minimal trapspaces), we find the **values of the modeloutput nodes in each attractor** (can be either $1$, $0$ or a dash ($-$): *active*, *inactive* or the node's activity oscillates between the two) and calculate the following average weighted score across all attractors:

\begin{equation}
  gl_{model} = \frac{\sum_{j=1}^{k}\sum_{i=1}^{n}ss_{ij} \times w_i}{k}
  (\#eq:modeloutputs)
\end{equation}

where $k$ is the number of attractors of the model, $n$ is the number of nodes defined in the `modeloutputs` file, $w_i$ their respective weights and $ss_{ij}$ is the state of node $i$ in the $j$-th attractor (can be one of $0$, $1$ or $0.5$ in case of a dash ^[And that's a good approximation when we are talking about boolean models. It could be though that this particular node that in the trapspace result has an activity defined by a dash ($-$) oscillates between $1000$ states, out of which it's active in $900$ of them and inactive in the rest. So a more correct value in that case would be a $0.9$]). 
We always normalize the `globaloutput` to the $[0,1]$ range by using the $max(gl)=\sum_{w_i>0}w_i$ and $min(gl)=\sum_{w_i<0}w_i$ values and calculating: 

\begin{equation}
  gl_{norm} = \frac{gl_{model}-min(gl)}{max(gl)-min(gl)}
  (\#eq:modeloutputsnorm)
\end{equation}

For example, for a boolean model that has $k=1$ attractor, Equation \@ref(eq:modeloutputs) becomes:

\begin{equation}
  gl_{model} = \sum_{i=1}^{n} ss_i \times w_i
  (\#eq:modeloutputs1ss)
\end{equation}

So, if we have a boolean model whose modeloutput nodes are defined as in the [example above](#modeloutputs) (a subset of the total model nodes) and which has $1$ trapspace where `RPS6KA1`=$1$, `MYC`=`TCF7`=$-$ and `CASP8`=`CASP9`=`FOXO3`=$0$, then using Equation \@ref(eq:modeloutputs1ss):

$$gl_{model}=1\times1+0.5\times1+0.5\times1+0\times-1+0\times-1+0\times-1=2$$

and since $min(gl)=-3$ and $max(gl)=+3$, the *normalized* globaloutput value is $gl_{norm}=\frac{2-(-3)}{3-(-3)}=0.833$.

## Configuration {-#gitsbeConfig}

includes parameters essential for the genetic algorithm simulation and general ones

### Global options {-}

### Export options {-}

Usually, given an input steady state and or the specified perturbations.

List:

- 
- 
-
- 

### Genetic Algorithm parameters {-#genAlgoParams}

#### Attractor Tool {-}

A summary of the possible **mutations** that can be applied to randomly chosen equations of a logical model are:

- Balance: `and not` <=> `or not`. This are essentially *link operator* mutations.
- Random: `(A or B)` <=> `(A and B)` (change of logical role)
- Shuffle: `(A or B)` <=> `(B or A)` (priority)
- Topology: `(A or B)` <=> `(B)` (addition and removal of regulation edges)


The large number of mutations in the initial phase ensures that a large variation in parameterization can be explored.
