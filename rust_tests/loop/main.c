int main(){
  while (1) {
    if(1==2) {
      break;
    } else {
      continue;
    }
  }
  return 0;
}

int aux(){
  for(int i = 0; i < 10; i++) {
    if(i==i+1) {
      break;
    } else {
      continue;
    }
  }
  return 0;
}

int aux_2(){
  do {
    if(1==2) {
      break;
    } else {
      continue;
    }
  } while(1==2);

  return 0;
}
