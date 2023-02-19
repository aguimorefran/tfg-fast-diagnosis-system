# FDS (Fast Diagnosis System)

![FDS Logo](fds-logo250.png)

FDS is a tool for fast diagnosis of diseases. The goal is to be able to diagnose in a fast way, with high accuracy, and low human cost, the disease a person might be suffering from, and without having to wait for someone to do the diagnosis.

The interested patient will be able to talk to a chatbot, which will ask him a series of questions, and based on the answers, will be able to diagnose the disease. If the diagnosis is not clear, the chatbot will ask for more information, and will try to diagnose again. If the diagnosis is still not clear, the chatbot will ask for a medical professional to take a look at the case.

If the chatbout diagnoses a disease with a high confidence, and the severity of the disease is high, the chatbot will put the patient in contact with a medical professional, so that the patient can be treated as soon as possible. If the severity of the disease is low, the chatbot will give the patient some advice on how to treat the disease, and will put the patient in a queue to be seen by a medical professional.

In both cases, the chatbot will advice taking certain medicines and drugs.

## How to run

### Requirements

- Docker. You can install it from [here](https://docs.docker.com/install/). To start the docker daemon, run `sudo service docker start`.
- Go through every README.md file in the root of every service, and follow the instructions.