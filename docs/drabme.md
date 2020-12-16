# Drabme {-}

## Description {-}

## Installation and Usage {-#drabme-install}

### Install {-}

### Example {-}

### Inputs {-#drabme-input}

### Outputs {-}

## Drugpanel {-}

## Perturbations {-}

## Configuration {-#drabme-config}

For a list of options that are common between Gitsbe and Drabme see [General] and [Attractor Tool] options.
We only include here the configuration options that can be used by Drabme alone:

- `max_drug_comb_size`. Example value: $2$.

  This option creates all combinations of drugs from the [drug panel](#drugpanel) file **up to and including** the given size.
  This option is only used when there is no [perturbations] file given by the user.
  If for example there are **3 drugs in the panel**: `A,B,C` and `max_drug_comb_size: 3` then the following drug perturbations are created (note that the order of the drugs is preserved in the higher-order combinations):
  
  :::{.blue-box .fitcontent}
  A  
  B  
  C  
  A&emsp;B  
  A&emsp;C  
  B&emsp;C  
  A&emsp;B&emsp;C  
  :::
